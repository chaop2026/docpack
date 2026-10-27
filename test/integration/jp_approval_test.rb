require "test_helper"

# The weekly approval: one button that schedules the blog post and arms the X
# thread, and the fingerprint that makes "approved" mean a specific version.
class JpApprovalTest < ActionDispatch::IntegrationTest
  def make_package(status: "draft", guard: { "violations" => [] }, **pkg)
    Post.create!(
      content_track: "jp", content_ep: 42, primary_locale: "ja", status: status,
      category: "privacy", slug: "jp-ep42-approval", title_ja: "承認テスト",
      body_ja: "<p>本文</p>", body_en: "<p>Body</p>", published_at: next_monday_9jst,
      package: { "ep" => 42, "track" => "jp", "x_thread" => %w[a b],
                 "x_reply_en" => "reply", "linkedin_text" => "li",
                 "guard" => guard }.merge(pkg)
    )
  end

  def make_topic(**overrides)
    BlogTopic.create!({ track: "jp", ep: 42, topic: "承認テスト", category: "privacy",
                        title_en: "Approval test", landing: "nyusatsu",
                        publish_on: next_monday_9jst.to_date }.merge(overrides))
  end

  def next_monday_9jst
    Time.use_zone("Asia/Tokyo") do
      d = Date.current + 1
      d += 1 until d.wday == 1
      Time.zone.local(d.year, d.month, d.day, 9, 0, 0)
    end
  end

  def login
    post admin_login_path, params: { password: ENV.fetch("ADMIN_PASSWORD", "docpack2025") }
  end

  # ── the transaction ─────────────────────────────────────────────────────────

  test "approval schedules the blog post and arms the X thread together" do
    post_rec = make_package
    topic = make_topic
    JpApproval.approve!(post_rec, topic: topic)
    post_rec.reload

    assert_equal "scheduled", post_rec.status
    assert post_rec.package["approved_at"].present?
    assert_equal JpApproval.version_for(post_rec), post_rec.package["approved_version"]
    assert_equal "pending", post_rec.package.dig("x", "state")

    due = Time.zone.parse(post_rec.package.dig("x", "due_at"))
    assert_equal post_rec.published_at + 3.hours, due
    assert_equal 12, due.in_time_zone("Asia/Tokyo").hour, "X goes out at 12:00 JST"
  end

  test "a social_skip week defers the thread to the following Monday at noon" do
    # v3 said "X only" for the year-end and Golden Week weeks; cross-review Q5
    # inverted it — those are the weeks a thread is least read and a blog post
    # is most patient.
    post_rec = make_package
    topic = make_topic(social_skip: true)
    JpApproval.approve!(post_rec, topic: topic)
    post_rec.reload

    due = Time.zone.parse(post_rec.package.dig("x", "due_at")).in_time_zone("Asia/Tokyo")
    assert_equal 1, due.wday
    assert_equal 12, due.hour
    assert_equal post_rec.published_at.in_time_zone("Asia/Tokyo").to_date + 7, due.to_date
    assert_equal true, post_rec.package.dig("x", "deferred_for_social_skip")
  end

  # ── what blocks it ──────────────────────────────────────────────────────────

  test "guard violations block approval" do
    post_rec = make_package(guard: { "violations" => [ "x_thread tweet 1: 編集上限" ] })
    topic = make_topic
    refute post_rec.approvable?(topic)
    assert_raises(ArgumentError) { JpApproval.approve!(post_rec, topic: topic) }
    assert_equal "draft", post_rec.reload.status
  end

  test "an import conflict blocks approval" do
    post_rec = make_package(import_conflict: { "at" => Time.current.iso8601, "content_hash" => "abc" })
    topic = make_topic
    refute post_rec.approvable?(topic)
    assert_raises(ArgumentError) { JpApproval.approve!(post_rec, topic: topic) }
  end

  test "an unverified verify_before topic blocks approval" do
    post_rec = make_package
    topic = make_topic(verify_before: true)
    refute post_rec.approvable?(topic)
    assert_raises(ArgumentError) { JpApproval.approve!(post_rec, topic: topic) }

    topic.update!(verified_at: Time.current)
    assert post_rec.approvable?(topic)
    assert_nothing_raised { JpApproval.approve!(post_rec, topic: topic) }
  end

  test "a missing publish time blocks approval" do
    post_rec = make_package
    post_rec.update_column(:published_at, nil)
    assert_raises(ArgumentError) { JpApproval.approve!(post_rec.reload, topic: make_topic) }
  end

  # ── the fingerprint ─────────────────────────────────────────────────────────

  test "editing the body after approval changes the fingerprint" do
    post_rec = make_package
    JpApproval.approve!(post_rec, topic: make_topic)
    recorded = post_rec.reload.package["approved_version"]

    post_rec.update!(body_ja: "<p>書き換えました</p>")
    refute_equal recorded, JpApproval.version_for(post_rec.reload),
                 "an edit must invalidate the approval, or X posts copy nobody agreed to"
  end

  test "moving the publish time changes the fingerprint" do
    # Approving a package for Monday and then moving it to Friday is a different
    # decision, so published_at is part of what is frozen.
    post_rec = make_package
    JpApproval.approve!(post_rec, topic: make_topic)
    recorded = post_rec.reload.package["approved_version"]

    post_rec.update!(published_at: post_rec.published_at + 4.days)
    refute_equal recorded, JpApproval.version_for(post_rec.reload)
  end

  test "an unrelated save does NOT change the fingerprint" do
    # view_count ticks on every page view; if that moved the fingerprint, every
    # approved thread would block itself as soon as someone read the article.
    post_rec = make_package
    JpApproval.approve!(post_rec, topic: make_topic)
    recorded = post_rec.reload.package["approved_version"]

    post_rec.increment!(:view_count)
    assert_equal recorded, JpApproval.version_for(post_rec.reload)
  end

  # ── unapproving ─────────────────────────────────────────────────────────────

  test "unapproving returns it to draft, cancels the thread, and keeps what was posted" do
    post_rec = make_package
    JpApproval.approve!(post_rec, topic: make_topic)
    post_rec.reload
    post_rec.update_column(:package, post_rec.package.deep_merge(
      "x" => { "tweets" => [ { "seq" => 1, "tweet_id" => "999", "state" => "done" } ] }
    ))

    JpApproval.unapprove!(post_rec.reload)
    post_rec.reload

    assert_equal "draft", post_rec.status
    assert_nil post_rec.package["approved_at"]
    assert_nil post_rec.package["approved_version"]
    assert_equal "cancelled", post_rec.package.dig("x", "state")
    assert_equal "999", post_rec.package.dig("x", "tweets", 0, "tweet_id"),
                 "the record of what is already live must survive — it is the only copy"
  end

  # ── the admin screen ────────────────────────────────────────────────────────

  test "the package page renders every part of the weekly decision" do
    post_rec = make_package
    make_topic
    login
    get admin_jp_package_path(42)

    assert_response :success
    assert_select "[data-jp-package=?]", "42"
    # Korean UI, Japanese content (S9). Both halves are asserted, because each
    # one alone passes on a wrong screen: checking only the Korean label passes
    # on a screen that translated the article too, and checking only the
    # Japanese title passes on the pre-S9 all-Japanese screen.
    assert_includes response.body, "승인"
    assert_includes response.body, post_rec.title_ja,
                    "the article's own Japanese title must NOT be translated — it is the content"

    # The old labels, by name. A blanket `refute_includes "承認"` was tried first
    # and was wrong: the fixture's title_ja is 「承認テスト」, so it matched the
    # CONTENT and failed on a screen that was already fully Korean. These seven
    # strings only ever appeared as chrome.
    [ "承認済", "未承認", "差し戻す", "公開予定", "添付なし", "カルーセル", "承認(無効)" ].each do |ja|
      refute_includes response.body, ja, "#{ja} is a pre-S9 Japanese UI string"
    end
    assert_includes response.body, "가중" # the weighted-length label, Korean since S9
    assert_includes response.body, "LinkedIn"
    assert_includes response.body, "P18"
  end

  test "the approve button is disabled and the reason is named when the guard failed" do
    make_package(guard: { "violations" => [ "x_thread tweet 1: 編集上限 140 を超えている" ] })
    make_topic
    login
    get admin_jp_package_path(42)

    assert_response :success
    assert_includes response.body, "승인(불가)"
    # The violation text itself stays as the guard wrote it — it names a file
    # and a Japanese rule, and translating a diagnostic would make it not match
    # what the build prints.
    assert_includes response.body, "編集上限"
  end

  test "approving and unapproving through the admin round-trips" do
    make_package
    make_topic
    login

    post admin_jp_package_approve_path(42)
    assert_redirected_to admin_jp_package_path(42)
    assert_equal "scheduled", Post.find_by(content_ep: 42).status

    post admin_jp_package_unapprove_path(42)
    assert_equal "draft", Post.find_by(content_ep: 42).status
  end

  test "the package page requires the admin session" do
    make_package
    get admin_jp_package_path(42)
    assert_redirected_to admin_login_path
  end

  # ── the two answers to an 'unknown' tweet, through the REAL routes ─────────
  #
  # XPublishJobTest builds these shapes by hand so its cases stay readable.
  # These two assert the controller actually writes that shape, which is what
  # stops the hand-built version from drifting away from production.

  def package_with_unknown_seq2
    post_rec = make_package
    make_topic
    post_rec.update_column(:package, post_rec.package.merge(
      "x" => { "state" => "unknown", "due_at" => 1.hour.ago.iso8601,
               "resume_requested" => true, # the legacy key, to prove it is dropped
               "tweets" => [
                 { "seq" => 1, "state" => "done", "tweet_id" => "i1" },
                 { "seq" => 2, "state" => "unknown", "tweet_id" => nil },
                 { "seq" => 3, "state" => "pending", "tweet_id" => nil }
               ] }
    ))
    post_rec.reload
  end

  test "「未送信として再開」 authorises exactly that one sequence" do
    post_rec = package_with_unknown_seq2
    login

    post admin_jp_package_tweet_unsent_path(42), params: { seq: 2 }
    post_rec.reload
    x = post_rec.package["x"]

    assert_equal [ 2 ], x["resume_seqs"], "and nothing else"
    assert_equal "partial_failed", x["state"]
    assert_equal "unknown", x["tweets"][1]["state"],
                 "the record of what happened stays until the re-send actually begins"
    refute x.key?("resume_requested"), "the legacy boolean must not linger"
  end

  test "「送信済みとして記録」 authorises nothing and clears any earlier authorisation" do
    post_rec = package_with_unknown_seq2
    login

    post admin_jp_package_tweet_unsent_path(42), params: { seq: 2 }
    assert_equal [ 2 ], post_rec.reload.package.dig("x", "resume_seqs")

    # The human looks again and finds it WAS on the timeline after all.
    post admin_jp_package_tweet_sent_path(42), params: { seq: 2, tweet_id: "9988" }
    post_rec.reload
    x = post_rec.package["x"]

    assert_equal "done", x["tweets"][1]["state"]
    assert_equal "9988", x["tweets"][1]["tweet_id"]
    assert_empty x["resume_seqs"],
                 "a tweet recorded as sent must not stay on the re-send list"
    refute x.key?("resume_requested")
  end

  test "an unknown tweet nobody has answered authorises nothing" do
    post_rec = package_with_unknown_seq2
    post_rec.update_column(:package, post_rec.package.merge(
      "x" => post_rec.package["x"].except("resume_requested")
    ))
    post_rec.reload

    assert_empty Array(post_rec.package.dig("x", "resume_seqs")),
                 "no button pressed, no authorisation — the job must stay put"
  end

  test "recording a LinkedIn URL is what makes P18 count it" do
    post_rec = make_package
    make_topic
    before = JpWeeklyKpi.new.p18_counts[:linkedin]

    login
    post admin_jp_package_linkedin_path(42), params: { linkedin_url: "https://www.linkedin.com/posts/x" }

    assert_equal "https://www.linkedin.com/posts/x", post_rec.reload.package.dig("posted", "linkedin_url")
    assert_equal before + 1, JpWeeklyKpi.new.p18_counts[:linkedin]
  end

  test "improve is refused on an approved package" do
    post_rec = make_package
    JpApproval.approve!(post_rec, topic: make_topic)
    login

    post improve_admin_post_path(post_rec), params: { instruction: "直して" }
    assert_redirected_to admin_jp_package_path(42)
    assert_match(/差し戻/, flash[:alert])
  end
end
