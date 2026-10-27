require "test_helper"

# JpContentGuard — the server half of content/jp/guard_rules.json.
#
# Every forbidden rule gets a positive AND a negative case. A guard tested only
# on text that violates it passes just as well when it has stopped matching
# anything at all.
class JpContentGuardTest < ActiveSupport::TestCase
  MUST = "提出先の指示を必ず確認してください。".freeze

  def guard(**overrides)
    JpContentGuard.new(**{
      surfaces: { "post_ja.md (body)" => "普通の本文です。\n#{MUST}" },
      article_ja: "普通の本文です。\n#{MUST}",
      article_en: nil, title: "短いタイトル", tweets: [], linkedin_text: nil, faq: []
    }.merge(overrides))
  end

  # ── the rule file itself ────────────────────────────────────────────────────

  test "every pattern in guard_rules.json compiles as a Ruby Regexp" do
    # The loader compiles eagerly for exactly this reason: a pattern written in
    # syntax Ruby cannot parse would otherwise never match, and a guard that has
    # silently stopped guarding looks like a guard that found nothing.
    assert_nothing_raised { JpContentGuard.rules }
    assert_operator JpContentGuard.rules[:forbidden].size, :>=, 15
    assert JpContentGuard.rules[:forbidden].all? { |r| r.re.is_a?(Regexp) }
  end

  test "the JS loader and this one read the same file" do
    # Not that they agree on behaviour — that cannot be asserted from Ruby — but
    # that there is ONE file and both point at it. The path is the whole claim.
    js = Rails.root.join("scripts", "content", "guard_rules.mjs").read
    assert_includes js, "content', 'jp', 'guard_rules.json"
    assert_equal Rails.root.join("content", "jp", "guard_rules.json"), JpContentGuard::RULES_PATH
    assert JpContentGuard::RULES_PATH.exist?
  end

  # ── forbidden words ─────────────────────────────────────────────────────────

  {
    "絶対"       => "絶対に安全です。",
    "唯一"       => "唯一の方法です。",
    "完全に"     => "完全に消えます。",
    "100%"       => "100% 読めません。",
    "一括"       => "一括で処理できます。",
    "あなた"     => "あなたの書類を扱います。",
    "弊社"       => "弊社のサービスです。",
    "タイムズカー" => "タイムズカーの事故では"
  }.each do |label, text|
    test "catches 「#{label}」" do
      v = guard(surfaces: { "s" => text }).violations
      assert v.any? { |x| x.include?("s:") }, "expected a violation for #{label}, got #{v.inspect}"
    end
  end

  # 防ぐ in every conjugation. The rule before S8 listed 防ぎます|防げます only,
  # so these five walked past it (cross-review Q4).
  %w[防ぐ 防ぎます 防げます 防いでいます 防がない 防ごう].each do |form|
    test "catches 防ぐ conjugation 「#{form}」" do
      assert guard(surfaces: { "s" => "情報漏えいを#{form}。" }).violations.any?,
             "「#{form}」 should be caught"
    end
  end

  # The negative half. 防 appears in plenty of words that are not the verb; if
  # these fired, the rule would be unusable and authors would learn to ignore it.
  %w[防止 防犯カメラ 消防署 予防する 防災].each do |word|
    test "does NOT catch 「#{word}」" do
      assert_empty guard(surfaces: { "s" => "#{word}について。" }).violations.grep(/fusegu/),
                   "「#{word}」 is not the verb 防ぐ"
    end
  end

  test "ordinary Japanese copy produces no violations" do
    assert_empty guard.violations
  end

  # ── the required line ───────────────────────────────────────────────────────

  test "required line must be its own line" do
    buried = "発注者により異なります。#{MUST} 指示が優先です。"
    v = guard(surfaces: { "post_ja.md (body)" => buried }, article_ja: buried).violations
    assert v.any? { |x| x.include?("独立した行") }, v.inspect
  end

  test "required line must end in the full stop" do
    no_stop = "本文です。\n提出先の指示を必ず確認してください"
    v = guard(surfaces: { "s" => no_stop }, article_ja: no_stop).violations
    assert v.any? { |x| x.include?("独立した行") }, v.inspect
  end

  test "required line in bold on its own line passes" do
    assert_empty guard(article_ja: "本文です。\n**#{MUST}**").violations
  end

  test "missing required line is reported as missing, not as misplaced" do
    v = guard(article_ja: "本文だけです。").violations
    assert v.any? { |x| x.include?("必須文") && !x.include?("独立した行") }, v.inspect
  end

  # ── conditional legal-claim sourcing ────────────────────────────────────────
  #
  # Four combinations, because this rule is a conditional and a conditional
  # tested on one branch is an assertion about nothing.

  LEGAL = "告知を求めることは制限されます。".freeze
  SOURCE = "出典: https://www.mhlw.go.jp/stf/newpage_13989.html （確認日: 2026-10-25）".freeze

  test "legal claim WITHOUT a source is a violation" do
    v = guard(article_ja: "#{LEGAL}\n#{MUST}").violations
    assert v.any? { |x| x.include?("法的主張") }, v.inspect
  end

  test "legal claim WITH a go.jp source and a confirmation date passes" do
    assert_empty guard(article_ja: "#{LEGAL}\n#{SOURCE}\n#{MUST}").violations
  end

  test "legal claim with a source but NO confirmation date is a violation" do
    v = guard(article_ja: "#{LEGAL}\nhttps://www.mhlw.go.jp/stf/newpage_13989.html\n#{MUST}").violations
    assert v.any? { |x| x.include?("確認日") }, v.inspect
  end

  test "NO legal claim and no source passes — the rule must not demand a citation" do
    # The point cross-review Q4 made: "every article needs an enforcement date"
    # invites a fabricated one. A how-to about dragging a file onto a page has
    # no statute to cite.
    assert_empty guard(article_ja: "ファイルをドラッグします。\n#{MUST}").violations
  end

  test "方法 does not read as a statute citation" do
    # 法 appears inside 方法・手法・用法. Without the lookbehind, every 手順
    # article would be demanding a go.jp URL.
    assert_empty guard(article_ja: "この方法により隠せます。手法を説明します。\n#{MUST}").violations
  end

  test "English legal claims are checked too" do
    # post_en.md is a parallel rewrite carrying the same claim in its own words;
    # the Japanese patterns can never match it.
    v = guard(article_en: "Under the Health Insurance Act, in force since 1 October 2020, this may be restricted.").violations
    assert v.any? { |x| x.start_with?("post_en.md: 法的主張") }, v.inspect
  end

  test "English legal claim with a source and Confirmed: date passes" do
    en = "Under the Health Insurance Act, in force since 1 October 2020, this may be restricted. " \
         "Source: https://www.mhlw.go.jp/stf/newpage_13989.html (Confirmed: 2026-10-25). " \
         "Always check the recipient's own instructions."
    assert_empty guard(article_en: en).violations.grep(/post_en/)
  end

  # ── weighted length ─────────────────────────────────────────────────────────
  #
  # twitter-text's default weighting: the listed ranges weigh 1, everything else
  # 2, a URL a flat 23, and an emoji cluster 2 for the whole cluster.

  test "half-width ASCII weighs 1 per character" do
    assert_equal 5, JpContentGuard.weighted_length("abcde")
  end

  test "full-width Japanese weighs 2 per character" do
    assert_equal 10, JpContentGuard.weighted_length("あいうえお")
  end

  test "a URL weighs a flat 23 however long it is" do
    short = JpContentGuard.weighted_length("https://a.co")
    long  = JpContentGuard.weighted_length("https://example.com/#{'x' * 300}")
    assert_equal 23, short
    assert_equal 23, long
  end

  test "a ZWJ emoji sequence weighs 2 for the whole cluster, not per code point" do
    family = "👨‍👩‍👧"
    assert_operator family.codepoints.length, :>, 2, "fixture must actually be a multi-code-point cluster"
    assert_equal 2, JpContentGuard.weighted_length(family)
  end

  test "mixed text adds up" do
    # 5 ASCII (5) + 2 spaces (2) + 3 JA (6) + 1 URL (23) = 36. The spaces count:
    # they are ASCII and weigh 1 each, which is easy to forget and is exactly
    # the kind of off-by-two that would put a tweet over the limit.
    assert_equal 36, JpContentGuard.weighted_length("hello あいう https://slimfile.net/safe/jp/nyusatsu/")
  end

  test "the editorial limit is measured in WEIGHTED length, not characters" do
    # 80 Japanese characters = 160 weighted: under the 280 platform cap, over
    # the 140 editorial one. Comparing 140 against a raw character count — which
    # the pipeline did until 2026-10-25 — would let this through.
    tweet = "あ" * 80
    assert_equal 160, JpContentGuard.weighted_length(tweet)
    v = guard(tweets: [ tweet, MUST ]).violations
    assert v.any? { |x| x.include?("編集上限") }, v.inspect
    assert v.none? { |x| x.include?("X の上限") }, "160 is under the platform cap"
  end

  test "over the platform cap is reported as unpostable, not as an editorial issue" do
    v = guard(tweets: [ "あ" * 200, MUST ]).violations
    assert v.any? { |x| x.include?("X の上限") && x.include?("投稿できません") }, v.inspect
  end

  test "a tweet inside both limits passes" do
    assert_empty guard(tweets: [ "あ" * 60, MUST ]).violations
  end

  # ── the other limits ────────────────────────────────────────────────────────

  test "title over 32 characters is a violation" do
    v = guard(title: "あ" * 33).violations
    assert v.any? { |x| x.start_with?("title:") }, v.inspect
  end

  test "title of exactly 32 characters passes" do
    assert_empty guard(title: "あ" * 32).violations
  end

  # Reads the limit from the rules file rather than hardcoding it (S9). The
  # number moved from `limits.linkedin_chars` to `linkedin.limits.chars` and
  # from 1300 to 1500 in the same round; a test with the old literal in it would
  # have passed for the wrong reason (1301 is now UNDER the limit) and reported
  # that the length check still worked.
  test "linkedin text over the character limit is a violation" do
    over = "a" * (JpContentGuard.linkedin_limits["chars"] + 1)
    v = guard(linkedin_text: over).violations
    assert v.any? { |x| x.start_with?("linkedin_en.md:") && x.include?("字以内") }, v.inspect
  end

  test "linkedin text exactly at the character limit passes" do
    at = "a" * JpContentGuard.linkedin_limits["chars"]
    v = guard(linkedin_text: at).violations
    refute v.any? { |x| x.include?("字以内") }, v.inspect
  end

  test "an FAQ with the wrong number of questions is a violation" do
    two = [ { "q" => "a", "a" => "b" }, { "q" => "c", "a" => "d" } ]
    v = guard(faq: two).violations
    assert v.any? { |x| x.start_with?("faq_ja.md:") }, v.inspect
  end

  test "an FAQ of exactly three passes, and no FAQ at all is not this check's business" do
    three = Array.new(3) { |i| { "q" => "q#{i}", "a" => "a#{i}" } }
    assert_empty guard(faq: three).violations
    assert_empty guard(faq: []).violations
  end

  test "the result carries a fingerprint of the rules it ran" do
    r = guard.result
    assert_equal [], r["violations"]
    assert r["checked_at"].present?
    assert_match(/\A[0-9a-f]{12}\z/, r["rules_version"])
  end
end
