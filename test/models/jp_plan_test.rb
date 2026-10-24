require "test_helper"

# content/jp/topics.json — the publication plan.
#
# These are invariants of a hand-maintained 33-row list, which is exactly the
# kind of file where a typo is invisible: a date that is a Tuesday looks like a
# date. Strategy v3 shipped with all 33 of them on the wrong weekday and nobody
# noticed until the cross-review counted.
class JpPlanTest < ActiveSupport::TestCase
  PLAN = JSON.parse(Rails.root.join("content", "jp", "topics.json").read).freeze
  EPISODES = PLAN["episodes"].freeze

  test "the plan has 33 episodes numbered 1..33 with no gaps or repeats" do
    assert_equal 33, EPISODES.length
    assert_equal (1..33).to_a, EPISODES.map { |e| e["ep"] }.sort
  end

  test "every publish_on is a Monday" do
    # The operating schedule depends on it: blog 09:00 JST Monday, X 12:00 JST
    # Monday, LinkedIn Tuesday. A Tuesday date here silently shifts a whole week.
    wrong = EPISODES.reject { |e| Date.parse(e["publish_on"]).wday == 1 }
    assert_empty wrong.map { |e| "ep#{e['ep']} #{e['publish_on']} (#{Date.parse(e['publish_on']).strftime('%A')})" }
  end

  test "publish_on starts at 2026-10-26 and advances exactly one week each episode" do
    dates = EPISODES.sort_by { |e| e["ep"] }.map { |e| Date.parse(e["publish_on"]) }
    assert_equal Date.new(2026, 10, 26), dates.first
    dates.each_cons(2) { |a, b| assert_equal 7, (b - a).to_i, "#{a} → #{b} is not one week" }
  end

  test "every episode declares the fields the pipeline reads" do
    EPISODES.each do |e|
      assert e["blog_title_ja"].present?, "ep#{e['ep']} has no blog_title_ja"
      assert_includes %w[手順 理由 比較], e["intent"], "ep#{e['ep']} intent"
      assert_includes [ true, false ], e["verify_before"], "ep#{e['ep']} verify_before"
      assert_includes [ true, false ], e["social_skip"], "ep#{e['ep']} social_skip"
      assert_includes %w[nyusatsu honnin aimae], e["landing"], "ep#{e['ep']} landing"
    end
  end

  test "verify_before is set on exactly ep30 and ep32" do
    # ep30 cites a rule that is not in force until 2027-04; ep32 describes batch
    # processing, which has not shipped.
    assert_equal [ 30, 32 ], EPISODES.select { |e| e["verify_before"] }.map { |e| e["ep"] }.sort
  end

  test "social_skip is set on exactly ep10 and ep12-28, the year-end and Golden Week weeks" do
    skipped = EPISODES.select { |e| e["social_skip"] }
    assert_equal [ 10, 28 ], skipped.map { |e| e["ep"] }.sort
    assert_equal Date.new(2026, 12, 28), Date.parse(skipped.min_by { |e| e["ep"] }["publish_on"])
    assert_equal Date.new(2027, 5, 3),   Date.parse(skipped.max_by { |e| e["ep"] }["publish_on"])
  end

  test "ep32 is blocked from being built or imported at all" do
    ep32 = EPISODES.find { |e| e["ep"] == 32 }
    assert ep32["blocked_until"].present?,
           "ep32 advertises batch processing; the pipeline must refuse to build it"
  end

  test "blog titles stay inside the 32-character limit" do
    too_long = EPISODES.reject { |e| e["blog_title_ja"].length <= JpContentGuard.limits["title_chars"] }
    assert_empty too_long.map { |e| "ep#{e['ep']} #{e['blog_title_ja'].length}字 #{e['blog_title_ja']}" }
  end

  test "no blog title uses a word the guard forbids" do
    # ep32's title contains 「複数書類をまとめて処理する」 — which the guard forbids
    # and which is exactly why that episode carries blocked_until. Everything
    # else must be clean, or the plan is scheduling work that cannot ship.
    offenders = EPISODES.reject { |e| e["blocked_until"].present? }.filter_map do |e|
      v = JpContentGuard.new(surfaces: { "topics.json" => e["blog_title_ja"] }).violations
      "ep#{e['ep']}: #{v.join('; ')}" if v.any?
    end
    assert_empty offenders
  end

  test "the readme states the publish_on rule and its anchor date" do
    # The derivation (strategy §4 minus one day) is non-obvious and lives in a
    # script; the file has to say so, or the next editor types a Tuesday.
    readme = PLAN["_readme"].join("\n")
    assert_includes readme, "publish_on"
    assert_includes readme, "2026-10-26"
  end
end
