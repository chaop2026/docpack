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

  # ── infrastructure errors must NOT be isolated ──────────────────────────

  # Only errors meaning "this record cannot be saved" are caught. A dropped
  # connection has to propagate: swallowing it would report every post as
  # invalid and let the job exit successfully, throwing away the Solid Queue
  # retry that would have published them.
  def with_connection_dropped
    victim = Post.new(slug: "job-infra", title_ko: "x")
    victim.define_singleton_method(:update!) { |*| raise ActiveRecord::ConnectionNotEstablished, "db gone" }

    relation = Object.new
    relation.define_singleton_method(:find_each) { |&block| block.call(victim) }

    Post.stub(:scheduled_ready, relation) { yield }
  end

  test "an error that is not a rejected record propagates so the queue can retry" do
    with_connection_dropped do
      assert_raises(ActiveRecord::ConnectionNotEstablished) { PublishScheduledPostsJob.perform_now }
    end
  end

  test "a dropped connection is not reported as a validation failure" do
    with_connection_dropped do
      assert_raises(ActiveRecord::ConnectionNotEstablished) { PublishScheduledPostsJob.perform_now }
    end

    perform_enqueued_jobs
    assert_empty mails_titled(REPORT_SUBJECT)
  end
end
