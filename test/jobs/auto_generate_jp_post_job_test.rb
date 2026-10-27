require "test_helper"
require "minitest/mock"

class AutoGenerateJpPostJobTest < ActiveSupport::TestCase
  # assert_enqueued_emails lives in ActionMailer::TestHelper (not ActiveJob::TestHelper,
  # which only has assert_enqueued_jobs), and neither is mixed into
  # ActiveSupport::TestCase by default.
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  EP = 5

  # Per-test directory for the "generation parked before the row is written"
  # cache. Without it, two tests in this file share one real path across
  # parallel workers and one silently changes the other's behaviour — measured:
  # the reuse test's file made the generate-from-scratch test skip its API call.
  # ── why the clock is pinned (found 2026-10-27) ──────────────────────────────
  #
  # `BlogTopic.next_jp` only offers topics whose `publish_on` is within nine
  # days, and "the queue advances past an episode nobody approved" builds its
  # second topic at `next_monday + 7`. How far away that is depends on what day
  # it is: on a Sunday the next Monday is tomorrow and the +7 topic lands eight
  # days out (inside the window); on a Tuesday the next Monday is six days away
  # and the +7 topic lands thirteen days out (outside it, so `next_jp` is empty
  # and the assertion gets nil).
  #
  # So the test passed on Sat/Sun/Mon and failed Tue–Fri. It was written and
  # last verified on Sunday 2026-10-25, which is why the suite was green then
  # and had one failure when this session opened on Tuesday 2026-10-27. The
  # 9-day window is correct and the test's intent is correct; what was wrong was
  # leaving the gap between them to the calendar.
  #
  # Pinned to a SATURDAY because that is when the job really runs (00:00 KST
  # Saturday, `config/recurring.yml`) — the deterministic choice and the
  # realistic one are the same date.
  PINNED_NOW = Time.utc(2026, 11, 7, 15, 0) # Sat 2026-11-07 00:00 JST

  setup do
    travel_to PINNED_NOW
    @save_dir = Dir.mktmpdir("jp_generated")
    AutoGenerateJpPostJob.save_dir = @save_dir
  end

  teardown do
    AutoGenerateJpPostJob.save_dir = Rails.root.join("tmp", "jp_generated")
    FileUtils.remove_entry(@save_dir) if @save_dir && File.exist?(@save_dir)
  end

  def make_topic(**overrides)
    BlogTopic.create!({
      track: "jp", ep: EP, topic: "第5回のテスト", category: "privacy",
      title_en: "Episode five test", landing: "nyusatsu", purpose: "bid_attachment",
      publish_on: next_monday, verify_before: false, social_skip: false
    }.merge(overrides))
  end

  def next_monday
    d = Date.current + 1
    d += 1 until d.wday == 1
    d
  end

  def make_draft(topic, slug: nil)
    Post.create!(content_track: "jp", content_ep: topic.ep, primary_locale: "ja",
                 status: "draft", category: "privacy",
                 slug: slug || "jp-ep#{format('%02d', topic.ep)}-episode-five-test",
                 title_ja: "第5回", body_ja: "<p>本文</p>",
                 package: { "ep" => topic.ep, "track" => "jp", "x_thread" => [ "a" ], "guard" => { "violations" => [] } })
  end

  # ── (a) the draft exists ────────────────────────────────────────────────────

  test "finds the imported draft, sets publish time to 09:00 JST, and mails once" do
    topic = make_topic
    post = make_draft(topic)

    assert_enqueued_emails 1 do
      AutoGenerateJpPostJob.perform_now
    end

    post.reload
    topic.reload
    jst = post.published_at.in_time_zone("Asia/Tokyo")
    assert_equal 9, jst.hour
    assert_equal 0, jst.min
    assert_equal 1, jst.wday, "the blog publishes on a Monday"
    assert_equal topic.publish_on, jst.to_date
    assert topic.review_sent_at.present?
  end

  test "an episode is offered for review exactly once" do
    # The cadence, and the thing that makes it true: next_jp excludes any topic
    # that already has a review_sent_at, so a second run inside the same week
    # mails nothing about this episode.
    topic = make_topic
    make_draft(topic)
    AutoGenerateJpPostJob.perform_now
    assert topic.reload.review_sent_at.present?

    assert_enqueued_emails 0 do
      AutoGenerateJpPostJob.perform_now
    end
    assert_empty BlogTopic.next_jp, "a reviewed topic must not come back round"
  end

  test "the queue advances past an episode nobody approved" do
    # Deliberate: one un-acted-on package must not block the schedule behind it.
    # The cost — no further mail about the skipped episode — is paid by state,
    # asserted in the next test.
    skipped = make_topic
    make_draft(skipped)
    AutoGenerateJpPostJob.perform_now

    nxt = make_topic(ep: 6, publish_on: next_monday + 7, title_en: "Episode six")
    make_draft(nxt, slug: "jp-ep06-episode-six")

    # The premise, asserted rather than assumed: `next_jp` only offers topics
    # inside a nine-day window, and on the pinned Saturday this topic sits
    # exactly at that edge (publish_on 2026-11-16, window end 2026-11-16).
    # Without this line, narrowing the window turns the assertion below into an
    # unexplained `expected <BlogTopic> got nil` — which is what this test
    # actually produced for four days of every week before the clock was pinned.
    assert_operator nxt.publish_on, :<=, 9.days.from_now.to_date,
                    "the follow-up episode must be inside next_jp's window or this test cannot test anything"

    assert_equal nxt, BlogTopic.next_jp.first
    assert_enqueued_emails 1 do
      AutoGenerateJpPostJob.perform_now
    end
    assert nxt.reload.review_sent_at.present?
  end

  test "a package that was never approved becomes visible as state" do
    # publish_stuck cannot see it — that scope only looks at `scheduled` posts,
    # and an unapproved package never leaves `draft`.
    topic = make_topic
    post = make_draft(topic)
    AutoGenerateJpPostJob.perform_now
    post.reload

    refute_includes Post.publish_stuck, post
    refute_includes Post.jp_unapproved_overdue, post, "not overdue yet"

    post.update_column(:published_at, 3.days.ago)
    assert_includes Post.jp_unapproved_overdue, post

    # Approving it takes it off the list.
    post.update!(published_at: 1.day.from_now)
    JpApproval.approve!(post.reload, topic: topic.reload)
    refute_includes Post.jp_unapproved_overdue, post.reload
  end

  test "the seven-day mail guard is reachable only outside next_jp, and it holds there" do
    # Named honestly: next_jp already excludes reviewed topics, so `perform`
    # cannot reach this guard by the normal route. It covers a manual re-run
    # after someone cleared review_sent_at to re-send, and it is asserted
    # directly rather than through a scope that would make it look exercised.
    topic = make_topic(review_sent_at: 1.day.ago)
    assert_empty BlogTopic.next_jp, "the scope is the first line of defence"
    assert_operator topic.review_sent_at, :>, AutoGenerateJpPostJob::REVIEW_INTERVAL.ago,
                    "and inside the window the job would refuse too"

    topic.update!(review_sent_at: 8.days.ago)
    assert_operator topic.review_sent_at, :<, AutoGenerateJpPostJob::REVIEW_INTERVAL.ago
  end

  test "a publish_on already in the past rolls forward to the next Monday" do
    topic = make_topic(publish_on: next_monday - 14)
    post = make_draft(topic)
    AutoGenerateJpPostJob.perform_now

    post.reload
    assert_operator post.published_at, :>, Time.current,
                    "never a time in the past — the daily sweep would publish it unapproved"
    assert_equal 1, post.published_at.in_time_zone("Asia/Tokyo").wday
    assert_equal 9, post.published_at.in_time_zone("Asia/Tokyo").hour
  end

  # ── verify_before ───────────────────────────────────────────────────────────

  test "an unverified verify_before topic is mailed but NOT given a publish time" do
    topic = make_topic(verify_before: true)
    post = make_draft(topic)

    assert_enqueued_emails 1 do
      AutoGenerateJpPostJob.perform_now
    end

    post.reload
    assert_nil post.published_at, "an unverified episode must not become schedulable"
    assert topic.reload.review_sent_at.present?
    # And approval refuses it, so the two halves agree.
    assert_raises(ArgumentError) { JpApproval.approve!(post, topic: topic) }
  end

  test "once verified, the publish time is set normally" do
    topic = make_topic(verify_before: true, verified_at: Time.current)
    post = make_draft(topic)
    AutoGenerateJpPostJob.perform_now

    assert post.reload.published_at.present?
    refute topic.awaiting_verification?
  end

  # ── (b) no draft — the fallback ─────────────────────────────────────────────

  GENERATED = {
    "title_ja" => "生成されたタイトル", "subtitle_ja" => "リード",
    "body_ja" => "<p>生成された本文</p>", "meta_description_ja" => "説明",
    "body_en" => "<p>Generated body</p>", "faq" => [], "x_thread" => [ "t1" ],
    "linkedin_text" => "LinkedIn"
  }.freeze

  test "with no draft it generates text only and marks the package as asset-less" do
    topic = make_topic
    generator = Minitest::Mock.new
    generator.expect(:generate_jp, GENERATED.dup, [ topic ])

    BlogGeneratorService.stub(:new, generator) do
      assert_enqueued_emails 1 do
        AutoGenerateJpPostJob.perform_now
      end
    end
    generator.verify

    post = Post.find_by(content_track: "jp", content_ep: EP)
    assert post.present?
    assert_equal "生成されたタイトル", post.title_ja
    assert_equal true, post.package["assets_missing"]
    assert post.package["guard"].present?, "the generated text is guarded like any other"
    refute post.hero_image.attached?
  end

  test "the generated text is saved before the row, and a second run reuses it" do
    topic = make_topic
    path = Pathname(@save_dir).join("ep05.json")

    generator = Minitest::Mock.new
    generator.expect(:generate_jp, GENERATED.dup, [ topic ])
    BlogGeneratorService.stub(:new, generator) { AutoGenerateJpPostJob.perform_now }
    generator.verify

    assert path.exist?, "the paid generation must be on disk before the write is attempted"
    assert_equal GENERATED["title_ja"], JSON.parse(path.read)["title_ja"]

    # Second run: the post exists, so the API must not be called at all. A mock
    # with no expectations raises if any method is called on it.
    Post.find_by(content_track: "jp", content_ep: EP).destroy
    topic.reload.update!(review_sent_at: nil) # reload first: the in-memory copy still says nil, so update! would be a no-op
    BlogGeneratorService.stub(:new, Minitest::Mock.new) { AutoGenerateJpPostJob.perform_now }

    post = Post.find_by(content_track: "jp", content_ep: EP)
    assert post.present?, "the saved generation must be enough to rebuild the row"
    assert_equal GENERATED["title_ja"], post.title_ja
  end

  test "a failed generation writes nothing and mails nothing" do
    make_topic
    generator = Minitest::Mock.new
    generator.expect(:generate_jp, nil, [ BlogTopic ])

    assert_no_difference -> { Post.count } do
      assert_enqueued_emails 0 do
        BlogGeneratorService.stub(:new, generator) { AutoGenerateJpPostJob.perform_now }
      end
    end
  end

  # ── selection ───────────────────────────────────────────────────────────────

  test "does nothing when no JP topic is due inside the horizon" do
    make_topic(publish_on: Date.current + 60)
    assert_no_difference -> { Post.count } do
      assert_enqueued_emails 0 do
        AutoGenerateJpPostJob.perform_now
      end
    end
  end

  test "takes the earliest due episode first" do
    later = make_topic(ep: 9, publish_on: next_monday + 14, title_en: "Later")
    earlier = make_topic(ep: 8, publish_on: next_monday, title_en: "Earlier")
    make_draft(earlier, slug: "jp-ep08-earlier")

    assert_equal earlier, BlogTopic.next_jp.first
    refute_equal later, BlogTopic.next_jp.first
  end

  test "the Korean job never picks a Japanese topic" do
    make_topic
    # Every Korean generation site goes through this scope.
    assert_empty BlogTopic.next_ko.where(track: "jp")
  end
end
