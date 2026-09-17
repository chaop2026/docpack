# Publishes every scheduled post whose time has come. Runs daily at 09:00 KST
# (config/recurring.yml) with nobody watching, which is what makes the failure
# handling below the interesting part of this file.
#
# It used to be four unguarded lines: `post.update!` inside `find_each`. That was
# survivable while nothing could reject a Post — and then 2026-09-18 added
# `validates :body_ko, if: published`. From that commit on, one post missing a
# Korean body would raise RecordInvalid and take **every post behind it in the
# batch** down with it, silently, for as long as the bad record sat in the queue.
# Correctness went up and availability went down, and the trade was not noticed
# at the time.
#
# ── What fails, and how each failure is made visible ────────────────────────
#
#   failure                        | isolation          | surfaced as
#   -------------------------------|--------------------|---------------------
#   update! rejects the record     | skip this post,    | logger.error per post
#   (RecordInvalid/RecordNotSaved) | batch continues    | + ONE admin email at
#                                  |                    | the end of the run
#   notification fails to enqueue  | skip the mail,     | logger.error
#                                  | post STAYS         |
#                                  | published          |
#   anything else (DB down, …)     | NOT isolated —     | the job fails, and
#                                  | it propagates      | Solid Queue retries
#   the failure report itself      | rescued            | logger.error
#
# The email matters more than it looks. Skipping a post trades one failure mode
# for another: instead of a stalled batch we now get a post that stays
# `scheduled` forever, and "forever" is exactly the kind of thing a log line in
# a container nobody tails will not tell anyone. So each run that skipped
# anything sends one message (one per run, not per post — a systemic problem
# must not turn into a mailbox flood). The job runs daily, so an unfixed post
# nags once a day until someone fixes it. The nagging IS the safety net.
#
# Infrastructure errors are deliberately NOT caught. Swallowing a dropped
# connection would report every post as "invalid" and let the job exit
# successfully, throwing away the retry that would have published them.
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  # Errors that mean *this record* cannot be saved. Narrow on purpose: these are
  # deterministic and per-post, so retrying the job would fail identically.
  RECORD_REJECTED = [ ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved ].freeze

  def perform
    skipped = []

    Post.scheduled_ready.find_each do |post|
      skipped << describe_failure(post) unless publish(post)
    end

    report(skipped) if skipped.any?
  end

  private

  # Returns true when the post is now published. Never raises for a rejected
  # record — that is the whole point — and never lets a mail problem undo a
  # publish that already happened.
  def publish(post)
    begin
      post.update!(status: "published")
    rescue *RECORD_REJECTED => e
      Rails.logger.error(
        "PublishScheduledPostsJob: '#{post.slug}' (id=#{post.id}) could not be published " \
        "and stays scheduled — #{e.class}: #{e.message}"
      )
      return false
    end

    Rails.logger.info("Published scheduled post: #{post.slug}")
    notify(post)
    true
  end

  # The post is live by the time this runs. A mail failure is logged and dropped:
  # rolling the publish back to keep the notification honest would hide a page
  # that is already public.
  def notify(post)
    BlogMailer.post_published(post).deliver_later
  rescue StandardError => e
    Rails.logger.error(
      "PublishScheduledPostsJob: '#{post.slug}' was published but its notification " \
      "could not be enqueued — #{e.class}: #{e.message}"
    )
  end

  # Plain strings and integers only — this crosses an ActiveJob serialization
  # boundary via deliver_later, where a Post or an exception object would not.
  def describe_failure(post)
    { "slug" => post.slug, "id" => post.id, "errors" => post.errors.full_messages.join(", ") }
  end

  def report(skipped)
    Rails.logger.error(
      "PublishScheduledPostsJob: #{skipped.size} post(s) stayed scheduled: " \
      "#{skipped.map { |f| f["slug"] }.join(", ")}"
    )

    # Only the mail is guarded, deliberately narrowly: there is no alert for the
    # alert, and losing it must not cost the run, which has already published
    # everything it could.
    begin
      BlogMailer.publish_failed(skipped).deliver_later
    rescue StandardError => e
      Rails.logger.error("PublishScheduledPostsJob: failure report could not be sent — #{e.class}: #{e.message}")
    end
  end
end
