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
#   update! rejects the record     | skip this post,    | the post becomes
#   (RecordInvalid/RecordNotSaved) | batch continues    | Post.publish_stuck
#                                  |                    | + publish_error
#                                  |                    | + logger.error
#                                  |                    | + ONE admin email
#   notification fails to enqueue  | skip the mail,     | logger.error
#                                  | post STAYS         |
#                                  | published          |
#   anything else (DB down, …)     | retried by this    | if the retries are
#                                  | job's retry_on;    | exhausted, Solid
#                                  | otherwise it       | Queue records it
#                                  | propagates         | (rake jobs:failed)
#   the failure report itself      | rescued            | logger.error
#
# Skipping a post trades one failure mode for another: instead of a stalled
# batch we get a post that stays `scheduled` forever. The first version of this
# fix answered that with an email, and the cross-review was right to call that
# insufficient — this app's production SMTP has already failed once (2026-04-07,
# 535-5.7.8), Solid Queue does not retry of its own accord, and nothing here
# read its failed-executions table. A lost alert had to be treated as a premise,
# not a risk.
#
# So the primary channel is now STATE, not notification. Post.publish_stuck
# derives "past due and still scheduled" from columns that are already there, so
# it survives a dead mailer, a dead queue, and the job never running at all.
# Three independent places read it: the /admin/posts banner, its `stuck` filter,
# and `rake blog:stuck` (exit 1), which needs neither a browser nor the admin
# password. This job's only job is to enrich that state with a REASON
# (publish_error) and to keep nagging by email. Both are best-effort; neither is
# load-bearing.
#
# Infrastructure errors are deliberately NOT isolated per post. Swallowing a
# dropped connection would report every post as "invalid" and let the job exit
# successfully, throwing away the replay that would have published them.
class PublishScheduledPostsJob < ApplicationJob
  queue_as :default

  # Safe to replay, which is why the retry policy lives here rather than on
  # ApplicationJob: Post.scheduled_ready stops returning a post the instant it
  # is published, so a second pass re-publishes nothing and re-notifies nobody.
  # Both exceptions mean the database was momentarily unavailable — they say
  # nothing about the work having happened. Bounded attempts: if the database is
  # down longer than this, the failure should become visible (rake jobs:failed)
  # rather than be retried out of sight.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  retry_on ActiveRecord::ConnectionNotEstablished, wait: :polynomially_longer, attempts: 3

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
      record_error(post, e)
      return false
    end

    Rails.logger.info("Published scheduled post: #{post.slug}")
    clear_error(post)
    notify(post)
    true
  end

  # Enrichment, not state. update_column on purpose: the record just failed
  # validation, so save would fail too — and writing the reason must not depend
  # on the record being valid. Post.publish_stuck already lists this post with or
  # without a reason, so a failure here costs legibility, never visibility.
  def record_error(post, error)
    post.update_column(:publish_error, "#{Time.current.iso8601} #{error.class}: #{error.message}")
  rescue StandardError => e
    Rails.logger.error("PublishScheduledPostsJob: could not record why '#{post.slug}' failed — #{e.class}: #{e.message}")
  end

  # A published post must not keep a stale reason around; the admin banner would
  # go on explaining a failure that no longer exists.
  def clear_error(post)
    post.update_column(:publish_error, nil) if post.publish_error.present?
  rescue StandardError => e
    Rails.logger.error("PublishScheduledPostsJob: could not clear the old error on '#{post.slug}' — #{e.class}: #{e.message}")
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
