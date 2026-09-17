# frozen_string_literal: true

require "test_helper"
require "minitest/mock" # Object#stub — not loaded by rails/test_help

# The job runs unattended at 09:00 KST, so these tests are about what happens
# when a post refuses to be published — and, just as much, about the failure
# mode the fix introduces: a skipped post stays `scheduled` forever unless
# something says so out loud.
class PublishScheduledPostsJobTest < ActiveJob::TestCase
  REPORT_SUBJECT = "발행 실패"
  NOTICE_SUBJECT = "새 글 발행"

  setup do
    # The fixtures include a scheduled post, but its published_at is in the
    # future, so scheduled_ready is empty until a test fills it.
    assert_empty Post.scheduled_ready, "expected no ready posts before the test sets them up"
    assert_empty Post.publish_stuck, "expected no stuck posts before the test sets them up"
    ActionMailer::Base.deliveries.clear
  end

  # A post that cannot be published: `validates :body_ko, if: published` rejects
  # it. Written with update_column to bypass the very validation under test —
  # nothing in the app builds this shape today, which is the point. The job has
  # to survive a record it has never seen.
  def ready_post(slug:, body_ko: "<p>본문</p>")
    post = Post.create!(
      title_ko: "예약 #{slug}", slug: slug, category: "pdf",
      status: "scheduled", published_at: 1.hour.ago, body_ko: "<p>임시</p>"
    )
    post.update_column(:body_ko, body_ko)
    post
  end

  def with_captured_log
    original = Rails.logger
    buffer = StringIO.new
    logger = ActiveSupport::Logger.new(buffer)
    # The default formatter writes the message alone, which would make an
    # assertion about the severity pass no matter what level was used.
    logger.formatter = ->(severity, _time, _progname, msg) { "#{severity} #{msg}\n" }
    Rails.logger = logger
    yield
    buffer.string
  ensure
    Rails.logger = original
  end

  def mails_titled(fragment)
    ActionMailer::Base.deliveries.select { |m| m.subject.to_s.include?(fragment) }
  end

  # ── one bad record must not cost the batch ──────────────────────────────

  test "a post that fails validation does not stop the posts behind it" do
    # Bad-first on purpose: find_each walks primary key order, so this is the
    # arrangement in which the unguarded update! destroyed the whole run.
    bad = ready_post(slug: "job-bad-first", body_ko: "")
    good_a = ready_post(slug: "job-good-a")
    good_b = ready_post(slug: "job-good-b")

    assert_nothing_raised { PublishScheduledPostsJob.perform_now }

    assert_equal "scheduled", bad.reload.status, "the invalid post must stay scheduled"
    assert_equal "published", good_a.reload.status
    assert_equal "published", good_b.reload.status
  end

  test "a bad record in the middle is skipped and the rest publish" do
    first = ready_post(slug: "job-mid-first")
    bad = ready_post(slug: "job-mid-bad", body_ko: "")
    last = ready_post(slug: "job-mid-last")

    PublishScheduledPostsJob.perform_now

    assert_equal "published", first.reload.status
    assert_equal "scheduled", bad.reload.status
    assert_equal "published", last.reload.status
  end

  test "every ready post publishes when nothing is wrong" do
    posts = 3.times.map { |i| ready_post(slug: "job-ok-#{i}") }

    PublishScheduledPostsJob.perform_now

    posts.each { |p| assert_equal "published", p.reload.status, p.slug }
  end

  # ── the skip has to be visible ──────────────────────────────────────────
  #
  # Skipping is a trade: a stalled batch becomes a post stuck at `scheduled`.
  # If that is only a log line, "stuck" means "stuck forever". These pin both
  # channels — the per-post log and the one-per-run email.

  test "the skipped post is named in the log at error level" do
    ready_post(slug: "job-logged-bad", body_ko: "")
    ready_post(slug: "job-logged-good")

    log = with_captured_log { PublishScheduledPostsJob.perform_now }

    assert_match(/ERROR.*job-logged-bad/, log)
    assert_match(/stays scheduled/, log)
    assert_no_match(/ERROR.*job-logged-good/, log)
  end

  test "a run that skipped anything sends one failure report and publishes the rest" do
    ready_post(slug: "job-report-bad-1", body_ko: "")
    ready_post(slug: "job-report-bad-2", body_ko: "")
    ready_post(slug: "job-report-good")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_equal 1, mails_titled(REPORT_SUBJECT).size
    assert_equal 1, mails_titled(NOTICE_SUBJECT).size
  end

  test "the failure report lists every skipped post once, however many there are" do
    ready_post(slug: "job-many-bad-1", body_ko: "")
    ready_post(slug: "job-many-bad-2", body_ko: "")
    ready_post(slug: "job-many-bad-3", body_ko: "")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    reports = mails_titled(REPORT_SUBJECT)
    assert_equal 1, reports.size, "a systemic failure must not become a mailbox flood"

    body = reports.first.body.encoded
    %w[job-many-bad-1 job-many-bad-2 job-many-bad-3].each { |slug| assert_includes body, slug }
    assert_includes reports.first.subject, "3건"
  end

  test "the report says which post and why, and links to the editor" do
    post = ready_post(slug: "job-why-bad", body_ko: "")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    body = mails_titled(REPORT_SUBJECT).first.body.encoded
    assert_includes body, "job-why-bad"
    assert_includes body, "/admin/posts/#{post.id}/edit"
    # The validation message itself, so the mail explains rather than just alerts.
    assert_match(/본문|body|Body/, body)
  end

  test "no failure report is sent when every post published" do
    ready_post(slug: "job-clean-a")
    ready_post(slug: "job-clean-b")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_empty mails_titled(REPORT_SUBJECT)
    assert_equal 2, mails_titled(NOTICE_SUBJECT).size
  end

  test "the report survives the ActiveJob serialization boundary" do
    # Plain strings and integers only. A Post or an exception object would raise
    # on the way into the queue — in production, not here, since deliver_later
    # serializes at enqueue time and the job under test would already be green.
    ready_post(slug: "job-serial-bad", body_ko: "")

    PublishScheduledPostsJob.perform_now
    assert_nothing_raised { perform_enqueued_jobs }

    assert_equal 1, mails_titled(REPORT_SUBJECT).size,
      "the failure report must actually render and deliver, not merely enqueue"
  end

  # ── published posts still get their notification ────────────────────────

  test "each published post is announced" do
    ready_post(slug: "job-notify-a")
    ready_post(slug: "job-notify-b")

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_equal 2, mails_titled(NOTICE_SUBJECT).size
  end

  test "a notification failure leaves the post published and the batch running" do
    ready_post(slug: "job-mailfail-a")
    ready_post(slug: "job-mailfail-b")

    BlogMailer.stub(:post_published, ->(_post) { raise StandardError, "smtp exploded" }) do
      log = with_captured_log { assert_nothing_raised { PublishScheduledPostsJob.perform_now } }
      assert_match(/was published but its notification/, log)
    end

    # Rolling the publish back to keep the notification honest would hide a page
    # that is already public, so it must not happen.
    assert_equal "published", Post.find_by(slug: "job-mailfail-a").status
    assert_equal "published", Post.find_by(slug: "job-mailfail-b").status
  end

  test "a failure report that cannot be sent does not cost the run" do
    good = ready_post(slug: "job-reportfail-good")
    ready_post(slug: "job-reportfail-bad", body_ko: "")

    BlogMailer.stub(:publish_failed, ->(_failures) { raise StandardError, "mailer down" }) do
      log = with_captured_log { assert_nothing_raised { PublishScheduledPostsJob.perform_now } }
      assert_match(/failure report could not be sent/, log)
    end

    assert_equal "published", good.reload.status
  end

  # ── the state channel, which does not depend on mail ────────────────────
  #
  # This is the part the first version of the fix got wrong. Skipping a post was
  # reported by email alone, and email is not a channel this app can lean on:
  # production SMTP failed on 2026-04-07 (535-5.7.8) and Solid Queue does not
  # retry of its own accord. The assertions below are written so that mail is
  # *broken* in the ones that matter.

  test "a skipped post is visible as state even when mail cannot be sent at all" do
    ready_post(slug: "job-state-bad", body_ko: "")
    good = ready_post(slug: "job-state-good")

    # Every mail path down: the per-post notification AND the failure report.
    BlogMailer.stub(:post_published, ->(_p) { raise StandardError, "smtp down" }) do
      BlogMailer.stub(:publish_failed, ->(_f) { raise StandardError, "smtp down" }) do
        assert_nothing_raised { PublishScheduledPostsJob.perform_now }
      end
    end

    perform_enqueued_jobs
    assert_empty ActionMailer::Base.deliveries, "this test is only meaningful with mail broken"

    # ...and the stuck post is still discoverable, from the database alone.
    assert_equal [ "job-state-bad" ], Post.publish_stuck.map(&:slug)
    assert_equal "published", good.reload.status
  end

  test "the reason is recorded on the post, not only in the log" do
    ready_post(slug: "job-reason-bad", body_ko: "")

    PublishScheduledPostsJob.perform_now

    post = Post.find_by(slug: "job-reason-bad")
    assert post.publish_error.present?, "the admin banner has nothing to show without this"
    assert_match(/RecordInvalid/, post.publish_error)
  end

  test "a post with no recorded reason is still reported as stuck" do
    # The job may never have reached it — Solid Queue was down, the scheduler
    # never fired, the process died. The derived scope must not need the job to
    # have run, because "the job never ran" is the failure that happened here in
    # April 2026.
    post = ready_post(slug: "job-never-tried")
    post.update_columns(published_at: 3.days.ago, publish_error: nil)

    assert_includes Post.publish_stuck.map(&:slug), "job-never-tried"
    assert_nil post.reload.publish_error
  end

  test "a stale reason is cleared once the post publishes" do
    post = ready_post(slug: "job-recovered", body_ko: "")
    PublishScheduledPostsJob.perform_now
    assert post.reload.publish_error.present?

    # The body gets filled in, the way a person would fix it.
    post.update_column(:body_ko, "<p>이제 본문이 있다</p>")
    PublishScheduledPostsJob.perform_now

    assert_equal "published", post.reload.status
    assert_nil post.publish_error, "the banner would keep explaining a failure that is over"
  end

  test "publishing normally leaves no stuck posts behind" do
    ready_post(slug: "job-clean-state-a")
    ready_post(slug: "job-clean-state-b")

    PublishScheduledPostsJob.perform_now

    assert_empty Post.publish_stuck
  end

  # ── retry policy ────────────────────────────────────────────────────────

  test "this job retries transient database errors because replaying it is a no-op" do
    handled = PublishScheduledPostsJob.rescue_handlers.map(&:first)
    assert_includes handled, "ActiveRecord::Deadlocked"
    assert_includes handled, "ActiveRecord::ConnectionNotEstablished"
  end

  test "replaying the job publishes nothing twice" do
    # The property the retry policy rests on: scheduled_ready stops returning a
    # post the moment it is published, so a second pass is a no-op.
    ready_post(slug: "job-replay-a")
    ready_post(slug: "job-replay-b")

    PublishScheduledPostsJob.perform_now
    published_at_values = Post.where(slug: %w[job-replay-a job-replay-b]).order(:slug).pluck(:published_at)

    PublishScheduledPostsJob.perform_now
    perform_enqueued_jobs

    assert_equal published_at_values,
      Post.where(slug: %w[job-replay-a job-replay-b]).order(:slug).pluck(:published_at)
    assert_equal 2, mails_titled(NOTICE_SUBJECT).size, "a replay must not re-announce"
  end

  # ── infrastructure errors must NOT be isolated ──────────────────────────

  # Only errors meaning "this record cannot be saved" are isolated. Anything
  # else must leave the per-post rescue — either to be retried by this job's own
  # retry_on, or to propagate and be recorded.
  def with_error_from_update(error_class, message = "boom")
    victim = Post.new(slug: "job-infra", title_ko: "x")
    victim.define_singleton_method(:update!) { |*| raise error_class, message }

    relation = Object.new
    relation.define_singleton_method(:find_each) { |&block| block.call(victim) }

    Post.stub(:scheduled_ready, relation) { yield }
  end

  test "a transient database error is retried, not mistaken for an invalid record" do
    # Before the retry policy this propagated. Now the job re-enqueues itself.
    # Either way the thing that must NOT happen is it being filed as a rejected
    # record: that would let the run finish "successfully" having published
    # nothing, and report perfectly good posts as broken.
    assert_enqueued_with(job: PublishScheduledPostsJob) do
      with_error_from_update(ActiveRecord::ConnectionNotEstablished, "db gone") do
        assert_nothing_raised { PublishScheduledPostsJob.perform_now }
      end
    end

    assert_empty mails_titled(REPORT_SUBJECT)
    assert_nil Post.find_by(slug: "job-infra"), "nothing should have been written"
  end

  test "an error outside both lists propagates and is recorded, not swallowed" do
    # Solid Queue does not retry on its own — ClaimedExecution#perform calls
    # failed_with and re-raises — so propagating is what puts this failure in
    # solid_queue_failed_executions, where `rake jobs:failed` can find it.
    # Swallowing it would leave no trace anywhere.
    with_error_from_update(ActiveRecord::StatementInvalid, "syntax error") do
      assert_raises(ActiveRecord::StatementInvalid) { PublishScheduledPostsJob.perform_now }
    end

    perform_enqueued_jobs
    assert_empty mails_titled(REPORT_SUBJECT)
  end

  test "a transient error does not leave a post looking stuck for the wrong reason" do
    with_error_from_update(ActiveRecord::ConnectionNotEstablished, "db gone") do
      PublishScheduledPostsJob.perform_now
    end

    assert_empty Post.publish_stuck, "a database blip is not a stuck post"
  end
end
