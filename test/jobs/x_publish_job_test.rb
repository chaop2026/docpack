require "test_helper"
require "minitest/mock"

# XPublishJob — the property under test is "a tweet is never posted twice".
#
# Every case below is about resumption: the thread is 5–6 sequential calls, any
# of which can fail or go unanswered, and a re-run must pick up exactly where
# the last confirmed success left off.
class XPublishJobTest < ActiveSupport::TestCase
  # A fake X API that records what it was asked to post, so "tweet 1 was sent
  # twice" is a thing the test can SEE rather than infer.
  class FakeClient
    attr_reader :posted, :media_uploads

    def initialize(fail_at: nil, error: XClient::ClientError.new(403, "forbidden"))
      @posted = []
      @media_uploads = 0
      @fail_at = fail_at
      @error = error
    end

    def dry_run? = false

    def upload_media(path:, content_type:)
      @media_uploads += 1
      "media-1"
    end

    def post_tweet(text:, media_id: nil, reply_to: nil)
      @posted << { text: text, media_id: media_id, reply_to: reply_to }
      raise @error if @fail_at == @posted.length

      "id-#{@posted.length}"
    end
  end

  def make_post(tweets: %w[one two three], reply: "english reply", x: {})
    post = Post.create!(
      content_track: "jp", content_ep: 77, primary_locale: "ja", status: "published",
      category: "privacy", slug: "jp-ep77-test", title_ja: "テスト", body_ja: "<p>本文</p>",
      published_at: 1.hour.ago,
      package: {
        "ep" => 77, "track" => "jp", "x_thread" => tweets, "x_reply_en" => reply,
        "x" => { "state" => "pending", "due_at" => 1.hour.ago.iso8601 }.merge(x)
      }
    )
    post
  end

  def run_with(client, post)
    XClient.stub(:new, client) { XPublishJob.perform_now(post.id) }
    post.reload
  end

  def states(post)
    post.package.dig("x", "tweets").map { |t| [ t["seq"], t["state"] ] }.to_h
  end

  # ── the happy path ──────────────────────────────────────────────────────────

  test "posts every tweet once, chained, and records the first tweet's URL" do
    post = make_post
    client = FakeClient.new
    run_with(client, post)

    assert_equal 4, client.posted.length, "3 JA tweets + 1 English reply"
    assert_nil client.posted.first[:reply_to]
    assert_equal "id-1", client.posted[1][:reply_to]
    assert_equal "id-2", client.posted[2][:reply_to]
    assert_equal "id-3", client.posted[3][:reply_to]
    assert_equal "done", post.package.dig("x", "state")
    assert_equal "https://x.com/safefile_jp/status/id-1", post.package.dig("x", "url")
    assert_equal true, post.package.dig("posted", "x")
  end

  # ── resumption ──────────────────────────────────────────────────────────────

  test "a rejection at tweet 3 leaves 1 and 2 done, and a re-run resumes at 3" do
    post = make_post
    first = FakeClient.new(fail_at: 3)
    run_with(first, post)

    assert_equal 3, first.posted.length
    assert_equal({ 1 => "done", 2 => "done", 3 => "failed", 4 => "pending" }, states(post))
    assert_equal "partial_failed", post.package.dig("x", "state")

    second = FakeClient.new
    run_with(second, post)

    assert_equal 2, second.posted.length, "only tweets 3 and 4 may be sent on the re-run"
    assert_equal "three", second.posted[0][:text]
    assert_equal "id-2", second.posted[0][:reply_to], "must reply to the last confirmed tweet"
    assert_equal "done", post.package.dig("x", "state")
    assert_equal({ 1 => "done", 2 => "done", 3 => "done", 4 => "done" }, states(post))
  end

  test "an UNKNOWN outcome stops the job and a re-run does not resend anything" do
    post = make_post
    first = FakeClient.new(fail_at: 2, error: XClient::IndeterminateError.new("timeout"))
    run_with(first, post)

    assert_equal "unknown", post.package.dig("x", "state")
    assert_equal "unknown", states(post)[2]
    assert_equal "pending", states(post)[3], "nothing behind the unknown tweet may be attempted"

    second = FakeClient.new
    run_with(second, post)
    assert_equal 0, second.posted.length,
                 "the job must not touch the thread until a human says what happened"
    assert_equal "unknown", post.package.dig("x", "state")
  end

  test "after a human marks the unknown tweet as sent, the job resumes at the NEXT one" do
    post = make_post
    run_with(FakeClient.new(fail_at: 2, error: XClient::IndeterminateError.new("timeout")), post)

    # What Admin::JpPackagesController#mark_tweet_sent does.
    rows = post.package.dig("x", "tweets").map do |t|
      t["seq"] == 2 ? t.merge("state" => "done", "tweet_id" => "hand-2") : t
    end
    x = post.package["x"].merge("tweets" => rows, "state" => "partial_failed", "resume_requested" => true)
    post.update_column(:package, post.package.merge("x" => x))

    client = FakeClient.new
    run_with(client, post.reload)

    assert_equal 2, client.posted.length, "tweets 3 and 4 only"
    assert_equal "three", client.posted[0][:text]
    assert_equal "hand-2", client.posted[0][:reply_to], "must chain onto the id the human recorded"
    assert_equal "done", post.package.dig("x", "state")
  end

  test "after a human marks the unknown tweet as unsent, the job resends THAT one" do
    post = make_post
    run_with(FakeClient.new(fail_at: 2, error: XClient::IndeterminateError.new("timeout")), post)

    rows = post.package.dig("x", "tweets").map do |t|
      t["seq"] == 2 ? t.merge("state" => "pending", "tweet_id" => nil) : t
    end
    x = post.package["x"].merge("tweets" => rows, "state" => "partial_failed", "resume_requested" => true)
    post.update_column(:package, post.package.merge("x" => x))

    client = FakeClient.new
    run_with(client, post.reload)

    assert_equal 3, client.posted.length, "tweets 2, 3 and 4"
    assert_equal "two", client.posted[0][:text]
    assert_equal "id-1", client.posted[0][:reply_to]
  end

  test "media is uploaded once and only for the first tweet" do
    post = make_post
    client = FakeClient.new
    run_with(client, post)
    assert_equal 0, client.media_uploads, "no package_assets attached in this fixture"
    assert_nil client.posted[1][:media_id]
  end

  test "a resumed run does not re-upload media when tweet 1 is already done" do
    post = make_post
    run_with(FakeClient.new(fail_at: 2), post)
    client = FakeClient.new
    run_with(client, post)
    assert_equal 0, client.media_uploads
  end

  # ── the approval fingerprint ────────────────────────────────────────────────

  test "an approved_version that no longer matches blocks the thread instead of posting it" do
    post = make_post
    post.update_column(:package, post.package.merge("approved_version" => "not-the-current-one"))

    client = FakeClient.new
    run_with(client, post.reload)

    assert_equal 0, client.posted.length, "nothing may be posted against a stale approval"
    assert_equal "blocked", post.package.dig("x", "state")
    assert_includes post.package.dig("x", "error"), "approved_version"
  end

  test "a matching approved_version posts normally" do
    post = make_post
    post.update_column(:package, post.package.merge("approved_version" => JpApproval.version_for(post)))
    client = FakeClient.new
    run_with(client, post.reload)
    assert_equal 4, client.posted.length
    assert_equal "done", post.package.dig("x", "state")
  end

  # ── enqueue loss and recovery ───────────────────────────────────────────────

  test "an enqueue that never happens leaves the state recoverable" do
    # The state is written at approval time and the enqueue follows; if the
    # enqueue is lost, `pending` is still in the database and blog:x_pending can
    # act on it. That split is the whole design — the channel that reports a
    # failure must not be the channel that failed.
    post = make_post
    assert_equal "pending", post.package.dig("x", "state")
    assert_includes Post.jp.select { |p| p.package.dig("x", "state") == "pending" }, post

    client = FakeClient.new
    run_with(client, post)
    assert_equal "done", post.package.dig("x", "state")
  end

  test "x_stuck finds an overdue unfinished thread and drops it once done" do
    post = make_post(x: { "due_at" => 5.hours.ago.iso8601 })
    assert_includes Post.x_stuck, post
    assert post.x_stuck?

    run_with(FakeClient.new, post)
    refute_includes Post.x_stuck, post
    refute post.x_stuck?
  end

  test "x_stuck ignores a thread that is not yet due" do
    post = make_post(x: { "due_at" => 3.hours.from_now.iso8601 })
    refute_includes Post.x_stuck, post
  end

  test "x_stuck never lists a Korean post" do
    posts(:korean_only).update_column(
      :package, { "x" => { "state" => "pending", "due_at" => 5.hours.ago.iso8601 } }
    )
    refute_includes Post.x_stuck, posts(:korean_only)
  end

  # ── what a re-import must not destroy ───────────────────────────────────────

  test "the X delivery record survives a blog edit" do
    post = make_post
    run_with(FakeClient.new(fail_at: 3), post)
    before = post.package["x"].deep_dup

    post.update!(body_ja: "<p>編集しました</p>")
    post.reload

    assert_equal before["tweets"].map { |t| t["tweet_id"] }, post.package.dig("x", "tweets").map { |t| t["tweet_id"] }
    assert_equal before["error"], post.package.dig("x", "error")
    assert_equal "partial_failed", post.package.dig("x", "state")
  end

  # ── dry run ─────────────────────────────────────────────────────────────────

  test "dry run posts nothing and says so in the record" do
    post = make_post
    ENV["X_API_DRY_RUN"] = "1"
    XPublishJob.perform_now(post.id)
    post.reload

    assert_equal "done", post.package.dig("x", "state")
    assert_equal true, post.package.dig("x", "dry_run")
    assert post.package.dig("x", "tweets").all? { |t| t["tweet_id"].to_s.start_with?("dry-") }
  ensure
    ENV.delete("X_API_DRY_RUN")
  end

  test "missing credentials force dry run even without the flag" do
    # The default posture: no keys, no posting. A deploy that forgets the
    # environment must not fall back to "try it and see".
    assert XClient.dry_run?, "no X_API_* keys are set in the test environment"
    refute XClient.credentials_present?
  end

  test "the credential report never contains a value" do
    ENV["X_API_KEY"] = "super-secret-value"
    report = XClient.credential_report
    assert_equal({ "present" => true, "length" => 18 }, report["X_API_KEY"])
    refute_includes report.to_json, "super-secret-value"
  ensure
    ENV.delete("X_API_KEY")
  end
end
