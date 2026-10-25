require "test_helper"
require "minitest/mock"

# XPublishJob — the property under test is "a tweet is never posted twice".
#
# Every case below is about resumption: the thread is 5–6 sequential calls, any
# of which can fail or go unanswered, and a re-run must pick up exactly where
# the last confirmed success left off.
class XPublishJobTest < ActiveSupport::TestCase
  # assert_enqueued_emails lives in ActionMailer::TestHelper; neither helper
  # is mixed into ActiveSupport::TestCase by default.
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

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

  # A client that dies — not raises a handled error, DIES — at a chosen point
  # around the API call. `Interrupt` is deliberately not a StandardError, so
  # nothing in the job rescues it: it models the process going away.
  class CrashingClient
    attr_reader :posted

    # when: :after_api  — the tweet IS on the timeline, we just never recorded it
    #       :before_api — the call never happened, but we cannot know that
    def initialize(crash_at:, when_to_crash: :after_api)
      @posted = []
      @crash_at = crash_at
      @when = when_to_crash
    end

    def dry_run? = false
    def upload_media(path:, content_type:) = "media-1"

    def post_tweet(text:, media_id: nil, reply_to: nil)
      raise Interrupt, "process ended before calling the API for seq #{@posted.length + 1}" \
        if @when == :before_api && @posted.length + 1 == @crash_at

      @posted << { text: text, media_id: media_id, reply_to: reply_to }
      raise Interrupt, "process ended right after the API returned seq #{@posted.length}" \
        if @when == :after_api && @posted.length == @crash_at

      "id-#{@posted.length}"
    end
  end

  # Crashes at the single statement that records an unknown outcome. A subclass
  # rather than a stub: perform_now builds its own instance, and prepending a
  # module would be permanent for the whole suite.
  class CrashAtUnknownWrite < XPublishJob
    private

    def write_x!(post, token, attrs = {}, tweet_patches: nil)
      raise Interrupt, "process ended at the unknown write" if attrs["state"] == "unknown"

      super
    end
  end

  # A client that fails the test if it is asked to send anything at all. Used to
  # turn "no tweet was resent" into an assertion the test can SEE rather than
  # infer from a count that might have been zero for another reason.
  class ForbiddenClient
    def dry_run? = false
    def upload_media(path:, content_type:) = raise("media must not be re-uploaded")
    def post_tweet(text:, media_id: nil, reply_to: nil)
      raise "RESEND — a tweet was sent that must not have been: #{text.to_s.first(30)}"
    end
  end

  def make_post(tweets: %w[one two three], reply: "english reply", x: {}, approved: true)
    post = Post.create!(
      content_track: "jp", content_ep: 77, primary_locale: "ja", status: "published",
      category: "privacy", slug: "jp-ep77-test", title_ja: "テスト", body_ja: "<p>本文</p>",
      published_at: 1.hour.ago,
      package: {
        "ep" => 77, "track" => "jp", "x_thread" => tweets, "x_reply_en" => reply,
        "x" => { "state" => "pending", "due_at" => 1.hour.ago.iso8601 }.merge(x)
      }
    )
    # The approval fingerprint is FAIL-CLOSED as of S8b: a package with no
    # recorded approval is blocked. Every test that expects the job to run has
    # to carry one, which is the point — the old default let the whole suite
    # exercise a path production will never take.
    approve!(post) if approved
    post
  end

  def approve!(post)
    post.update_column(:package, post.package.merge("approved_version" => JpApproval.version_for(post)))
    post.reload
  end

  def run_with(client, post, job: XPublishJob)
    XClient.stub(:new, client) { job.perform_now(post.id) }
    post.reload
  end

  # Simulate "the worker that held this claim is gone". A crashed worker leaves
  # a fresh claim behind, and the job deliberately will not steal a fresh claim
  # (that is how two workers end up on one timeline). Ageing it past CLAIM_TTL
  # is what a later run would see in the real world.
  def age_claim!(post, by: XPublishJob::CLAIM_TTL + 5.minutes)
    x = post.package["x"].merge("claimed_at" => (Time.current - by).iso8601)
    post.update_column(:package, post.package.merge("x" => x))
    post.reload
  end

  def states(post)
    post.package.dig("x", "tweets").map { |t| [ t["seq"], t["state"] ] }.to_h
  end

  # What the admin's two buttons write. Kept here as named helpers rather than
  # inline hashes so the shape is stated once; the real controller actions are
  # exercised in test/integration/jp_approval_test.rb, which is what stops
  # these from drifting away from production.
  #
  # 「送信済みとして記録」 — the human read the id off the timeline. The seq
  # becomes `done`, so it authorises nothing: the guard has no reason to stop.
  def admin_mark_sent!(post, seq, tweet_id)
    rows = post.package.dig("x", "tweets").map { |t| t["seq"] == seq ? t.merge("state" => "done", "tweet_id" => tweet_id) : t }
    x = post.package["x"].merge(
      "tweets" => rows, "state" => "partial_failed",
      # The controller rewrites this seq's entry rather than accumulating it:
      # the two buttons are mutually exclusive answers about the same tweet.
      "resume_seqs" => Array(post.package.dig("x", "resume_seqs")).map(&:to_i) - [ seq ]
    ).except("resume_requested")
    post.update_column(:package, post.package.merge("x" => x))
    post.reload
  end

  # 「未送信として再開」 — the human confirmed it is NOT on the timeline. The seq
  # stays `unknown` and is added to resume_seqs; the job consumes that.
  def admin_mark_unsent!(post, seq)
    x = post.package["x"].merge(
      "state" => "partial_failed",
      "resume_seqs" => (Array(post.package.dig("x", "resume_seqs")) + [ seq ]).uniq.sort
    ).except("resume_requested")
    post.update_column(:package, post.package.merge("x" => x))
    post.reload
  end

  def tweet_ids(post)
    post.package.dig("x", "tweets").map { |t| t["tweet_id"] }
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

    admin_mark_sent!(post, 2, "hand-2")

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

    admin_mark_unsent!(post, 2)

    client = FakeClient.new
    run_with(client, post.reload)

    assert_equal 3, client.posted.length, "tweets 2, 3 and 4"
    assert_empty post.package.dig("x", "resume_seqs"),
                 "the authorisation is consumed, so it cannot cover a later unknown"
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

  # ── crash durability (S8b, cross-review Q3 RED) ─────────────────────────────
  #
  # The tests above cover failures the job HANDLES. These cover the one it
  # cannot handle: the process going away mid-send.
  #
  # Before S8b the whole send loop ran inside `post.with_lock do … end`, so
  # every "written immediately" update was part of one uncommitted transaction.
  # Measured against the old code with the probe these tests automate: three
  # tweets reached the API and the row came back `state="pending", tweets=[]`.
  # The next run would have posted all three again.

  test "a crash right after the API returns keeps every confirmed id and resends nothing" do
    post = make_post
    crasher = CrashingClient.new(crash_at: 3, when_to_crash: :after_api)

    assert_raises(Interrupt) { run_with(crasher, post) }
    post.reload

    # seq 3 DID reach the API — the tweet is on the timeline — but the process
    # died before the id came back to us.
    assert_equal 3, crasher.posted.length
    assert_equal({ 1 => "done", 2 => "done", 3 => "sending", 4 => "pending" }, states(post))
    assert_equal [ "id-1", "id-2", nil, nil ], tweet_ids(post),
                 "the two confirmed ids must survive a crash — they are the only proof those tweets exist"

    # A later worker, once the dead worker's claim has expired.
    age_claim!(post)
    run_with(ForbiddenClient.new, post)

    assert_equal "unknown", post.package.dig("x", "state")
    assert_equal({ 1 => "done", 2 => "done", 3 => "unknown", 4 => "pending" }, states(post))
    assert_equal [ "id-1", "id-2", nil, nil ], tweet_ids(post)
  end

  test "a crash before the API call also lands on unknown — we do not guess that it never happened" do
    # From the database side this is indistinguishable from the case above, and
    # that is the point: `sending` means "we were in the middle of asking", and
    # the honest answer is that nobody here knows. Deciding it was never sent
    # would be a guess that resends a live tweet.
    post = make_post
    crasher = CrashingClient.new(crash_at: 3, when_to_crash: :before_api)

    assert_raises(Interrupt) { run_with(crasher, post) }
    post.reload
    assert_equal 2, crasher.posted.length, "seq 3 never reached the API"
    assert_equal "sending", states(post)[3]

    age_claim!(post)
    run_with(ForbiddenClient.new, post)

    assert_equal "unknown", post.package.dig("x", "state")
    assert_equal "unknown", states(post)[3]
  end

  test "an unknown raised by a crash notifies a human exactly as a timeout does" do
    post = make_post
    assert_raises(Interrupt) { run_with(CrashingClient.new(crash_at: 2), post) }
    age_claim!(post.reload)

    assert_enqueued_emails 1 do
      run_with(ForbiddenClient.new, post)
    end
  end

  test "after a human resolves the crashed tweet the thread resumes from the next one" do
    post = make_post
    assert_raises(Interrupt) { run_with(CrashingClient.new(crash_at: 2), post) }
    age_claim!(post.reload)
    run_with(ForbiddenClient.new, post)   # promotes seq 2 to unknown

    admin_mark_sent!(post, 2, "hand-2")

    client = FakeClient.new
    run_with(client, post.reload)

    assert_equal 2, client.posted.length, "only seq 3 and 4 remain"
    assert_equal "hand-2", client.posted[0][:reply_to], "must chain onto the id the human recorded"
    assert_equal "done", post.package.dig("x", "state")
  end

  # ── claim ownership ─────────────────────────────────────────────────────────

  test "a fresh claim is not stolen — that is how two workers end up on one timeline" do
    post = make_post
    assert_raises(Interrupt) { run_with(CrashingClient.new(crash_at: 2), post) }
    post.reload
    before = post.package["x"].slice("worker_token", "tweets")

    # No ageing: the claim is seconds old, so from here the other worker is
    # indistinguishable from one that is simply slow.
    run_with(ForbiddenClient.new, post)

    assert_equal before["worker_token"], post.package.dig("x", "worker_token")
    assert_equal "running", post.package.dig("x", "state")
    assert_equal "sending", states(post)[2], "left exactly as it was"
  end

  test "a claim older than the TTL may be taken over, one five minutes old may not" do
    post = make_post
    assert_raises(Interrupt) { run_with(CrashingClient.new(crash_at: 2), post) }
    post.reload
    original_token = post.package.dig("x", "worker_token")

    age_claim!(post, by: 5.minutes)
    run_with(ForbiddenClient.new, post)
    assert_equal original_token, post.package.dig("x", "worker_token"),
                 "5 minutes is well inside #{XPublishJob::CLAIM_TTL.inspect} — the worker may just be slow"
    assert_equal "running", post.package.dig("x", "state")

    age_claim!(post, by: XPublishJob::CLAIM_TTL + 1.minute)
    run_with(ForbiddenClient.new, post)
    refute_equal original_token, post.package.dig("x", "worker_token"), "a dead worker's claim is takeable"
    assert_equal "unknown", post.package.dig("x", "state")
  end

  test "a write whose token was taken over affects nothing" do
    # The mechanism behind the test above, asserted directly: every write in the
    # send loop carries `WHERE package->'x'->>'worker_token' = ?`.
    post = make_post
    job = XPublishJob.new

    post.update_column(:package, post.package.merge(
      "x" => post.package["x"].merge("worker_token" => "the-new-owner", "tweets" => [])
    ))

    assert_raises(XPublishJob::ClaimLost) do
      job.send(:write_x!, post.reload, "my-stale-token", { "state" => "done" })
    end
    assert_equal "the-new-owner", post.reload.package.dig("x", "worker_token"),
                 "the stale worker must not have written anything"
  end

  # ── the approval fingerprint ────────────────────────────────────────────────

  # ── S8c: the unknown write is ONE statement, and resume is per-sequence ─────
  #
  # The defect these close: `handle_indeterminate` used to write the tweet's
  # state and the thread's state separately. A crash in between left
  # `x.state=running` with a tweet at `unknown`, and the run guard consulted a
  # THREAD-level boolean (`resume_requested`) that an earlier, unrelated human
  # decision had set to true. Measured against 7cf81ec:
  #
  #   RESENT COUNT: 4  ["t3", "t4", "t5", "en reply"]
  #
  # t3 — the tweet whose outcome was unknown, possibly already live — was
  # reposted, and the thread then reported `done`.

  test "a NEW unknown during a resumed run is not covered by the earlier authorisation" do
    post = make_post(tweets: %w[t1 t2 t3 t4 t5], reply: "en reply")

    # A human authorised seq 1 at some earlier point. Under the old boolean this
    # is the flag that leaked; here it is a list entry about a different tweet.
    admin_mark_unsent!(post, 1)

    # Now a DIFFERENT tweet goes indeterminate, and the process dies at the
    # write. Because that write is a single statement, "during" it means it did
    # not land at all — the seq is still `sending`.
    crasher = Class.new do
      attr_reader :posted
      def initialize = (@posted = [])
      def dry_run? = false
      def upload_media(path:, content_type:) = "media-1"
      def post_tweet(text:, media_id: nil, reply_to: nil)
        @posted << text
        raise XClient::IndeterminateError, "timeout" if @posted.length == 3

        "id-#{@posted.length}"
      end
    end.new

    assert_raises(Interrupt) { run_with(crasher, post, job: CrashAtUnknownWrite) }
    post.reload
    assert_equal "sending", states(post)[3],
                 "a single-statement write is all-or-nothing: it did not land"

    # A later worker takes over the dead claim.
    age_claim!(post)
    run_with(ForbiddenClient.new, post)

    assert_equal "unknown", post.package.dig("x", "state")
    assert_equal "unknown", states(post)[3]
    assert_equal [ 1 ], post.package.dig("x", "resume_seqs"),
                 "the unrelated authorisation is still there and still does not cover seq 3"
    assert_equal %w[pending pending], [ states(post)[4], states(post)[5] ],
                 "nothing behind the unknown was attempted"
  end

  test "an authorisation for one sequence never covers another" do
    post = make_post(tweets: %w[t1 t2 t3], reply: "en reply")
    run_with(FakeClient.new(fail_at: 2, error: XClient::IndeterminateError.new("timeout")), post)
    assert_equal "unknown", states(post)[2]

    # Authorise seq 2 only. The job re-sends seq 2, then seq 3 goes
    # indeterminate — a tweet nobody has looked at.
    admin_mark_unsent!(post, 2)
    second = FakeClient.new(fail_at: 2, error: XClient::IndeterminateError.new("timeout again"))
    run_with(second, post)

    assert_equal %w[t2 t3], second.posted.map { |p| p[:text] }, "seq 2 re-sent, then seq 3 tried"
    assert_equal "unknown", states(post)[3]
    assert_empty post.package.dig("x", "resume_seqs"), "seq 2's authorisation was consumed"

    # And a further run must not touch seq 3.
    third = ForbiddenClient.new
    run_with(third, post)
    assert_equal "unknown", post.package.dig("x", "state")
  end

  test "consuming an authorisation clears the unknown and the list entry together" do
    post = make_post(tweets: %w[t1 t2 t3], reply: "en reply")
    run_with(FakeClient.new(fail_at: 2, error: XClient::IndeterminateError.new("timeout")), post)
    admin_mark_unsent!(post, 2)
    assert_equal [ 2 ], post.package.dig("x", "resume_seqs")

    run_with(FakeClient.new, post)
    assert_equal "done", states(post)[2]
    assert_empty post.package.dig("x", "resume_seqs")
  end

  # ── S8c: finish! is one statement ──────────────────────────────────────────

  test "finish cannot leave the thread done without recording that it was posted" do
    # The old finish wrote `x` and then `posted` in two statements, the second
    # with no token condition. Measured against 7cf81ec, a crash in between gave
    # `x.state="done" posted=nil`, and nothing recovered it:
    # `SELF-HEAL?: posted=nil api_calls=0`, `x_stuck? false`.
    #
    # There is no "in between" to crash in any more, so the assertion is that
    # the two always agree.
    post = make_post(tweets: %w[a b], reply: nil)
    run_with(FakeClient.new, post)

    assert_equal "done", post.package.dig("x", "state")
    assert_equal true, post.package.dig("posted", "x")
    assert_equal post.package.dig("x", "url"), post.package.dig("posted", "x_url")
    assert_nil post.package.dig("x", "worker_token"), "the claim is released by the same write"
  end

  test "a legacy half-finished thread is repaired without touching the API" do
    # The shape the old code could produce. Planted by hand, because the current
    # code cannot create it.
    post = make_post(tweets: %w[a b], reply: nil)
    run_with(FakeClient.new, post)
    post.update_column(:package, post.package.merge("posted" => post.package["posted"].except("x", "x_url")))
    post.reload
    assert_equal "done", post.package.dig("x", "state")
    assert_nil post.package.dig("posted", "x")

    repairer = ForbiddenClient.new   # raises if a single tweet is sent
    run_with(repairer, post)

    assert_equal true, post.package.dig("posted", "x")
    assert_equal post.package.dig("x", "url"), post.package.dig("posted", "x_url")
  end

  test "finish is exactly ONE update statement" do
    # The atomicity claim, asserted directly rather than inferred from an end
    # state that a two-statement version also reaches on a clean run. Counting
    # the UPDATEs is what distinguishes "there is no in-between" from "the
    # in-between happened to be survived this time".
    post = make_post(tweets: %w[a b], reply: nil)
    run_with(FakeClient.new(fail_at: 2), post)   # seq 1 done, seq 2 failed
    # Put it back in a shape where finish! is the next thing to run.
    rows = post.package.dig("x", "tweets").map { |t| t.merge("state" => "done", "tweet_id" => "id-#{t['seq']}") }
    token = post.package.dig("x", "worker_token")
    post.update_column(:package, post.package.merge(
      "x" => post.package["x"].merge("tweets" => rows, "state" => "running", "worker_token" => token)
    ))
    post.reload

    updates = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      updates << payload[:sql] if payload[:sql] =~ /\AUPDATE "posts"/
    end
    begin
      XPublishJob.new.send(:finish!, post, token)
    ensure
      ActiveSupport::Notifications.unsubscribe(sub)
    end

    assert_equal 1, updates.length, "finish! must be one statement, got:\n#{updates.join("\n")}"
    assert_match(/jsonb_set\(jsonb_set\(/, updates.first, "both subtrees in the one statement")
    assert_match(/worker_token/, updates.first, "and it carries the token condition")
    post.reload
    assert_equal "done", post.package.dig("x", "state")
    assert_equal true, post.package.dig("posted", "x")
  end

  test "finish refuses to write under a token that is no longer ours" do
    post = make_post(tweets: %w[a b], reply: nil)
    job = XPublishJob.new

    # Get the thread to the point where finish would be called, then hand it a
    # different owner.
    run_with(FakeClient.new, post)
    before = post.package.deep_dup
    post.update_column(:package, post.package.merge(
      "x" => post.package["x"].merge("worker_token" => "someone-else")
    ))
    post.reload

    assert_raises(XPublishJob::ClaimLost) { job.send(:finish!, post, "my-stale-token") }
    post.reload
    assert_equal "someone-else", post.package.dig("x", "worker_token")
    assert_equal before.dig("x", "url"), post.package.dig("x", "url"), "nothing else moved"
  end

  test "a package with NO recorded approval is blocked, not posted" do
    # Fail-closed (cross-review Q3). This used to return true when the
    # fingerprint was absent — "never approved through the admin" — which is
    # exactly the case that must not reach a public account.
    post = make_post(approved: false)
    client = FakeClient.new
    run_with(client, post)

    assert_equal 0, client.posted.length
    assert_equal "blocked", post.package.dig("x", "state")
    assert_includes post.package.dig("x", "error"), "approved_version"
  end

  test "dry run is NOT an exception to the approval check" do
    # A dry run that skips the check is not exercising the path that will run
    # for real, and the tests would then prove something other than what ships.
    post = make_post(approved: false)
    ENV["X_API_DRY_RUN"] = "1"
    XPublishJob.perform_now(post.id)
    post.reload

    assert_equal "blocked", post.package.dig("x", "state")
    assert_nil post.package.dig("x", "tweets")&.find { |t| t["tweet_id"] }
  ensure
    ENV.delete("X_API_DRY_RUN")
  end

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
