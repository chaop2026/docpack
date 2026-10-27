# The server half of the JP content rules.
#
# Reads content/jp/guard_rules.json — the SAME file scripts/content/guard_rules.mjs
# reads on the Mac. Before S8 the rules lived only in make_episode.mjs as JS
# constants, so the server enforced nothing; cross-review Q4 asked for one
# source, because a rule checked in one place and trusted in the other is a rule
# that exists in one place. That is not theoretical here: ep01 shipped
# 「複数枚をまとめて読み込めます」 with a clean build because the guard of the day
# was reading only the Japanese body.
#
# ── This service never edits anything ──────────────────────────────────────
#
# It reports. Rewriting an author's sentence to satisfy a regex produces copy
# nobody chose, and the damage is invisible once it is published. A violation
# blocks the 「승인」 button and is listed in red at the top of the review email;
# the import still happens, so a human can look at the package and decide.
#
# ── What a clean result does NOT mean ───────────────────────────────────────
#
# Passing `legal_claim` means a *.go.jp URL and a 確認日 are sitting next to the
# claim. It does NOT mean the source says what the article says it says. The
# regex cannot read. Likewise the first-person-victim pattern catches one shape
# and not the idea. scripts/content/README.md keeps the enforced and the
# human-held rules in two separate tables for exactly this reason.
class JpContentGuard
  RULES_PATH = Rails.root.join("content", "jp", "guard_rules.json")

  class RuleFileError < StandardError; end

  Rule = Struct.new(:id, :re, :why, keyword_init: true)

  class << self
    def rules
      # Reloaded per-call in development so an edit to the JSON takes effect
      # without a restart; memoised everywhere else.
      return load_rules if Rails.env.development? || Rails.env.test?

      @rules ||= load_rules
    end

    def limits
      rules[:limits]
    end

    def must_line
      rules[:must_line]
    end

    # The LinkedIn limits, by the name the views and tests use. One accessor so
    # the number has one home: `limits["linkedin_chars"]` was deleted in S9
    # rather than kept as an alias, because an alias is how the two copies
    # drifted in the first place.
    def linkedin_limits
      rules[:linkedin][:limits]
    end

    private

    def load_rules
      raw = JSON.parse(File.read(RULES_PATH))

      {
        must_line: raw.fetch("must_line"),
        limits: raw.fetch("limits"),
        forbidden: raw.fetch("forbidden").map { |f| compile(f, "forbidden") },
        legal_claim_patterns: raw.dig("legal_claim", "claim_patterns").map { |p| compile(p, "legal_claim") },
        legal_source_url: compile({ "id" => "source_url_re", "re" => raw.dig("legal_claim", "source_url_re") }, "legal_claim"),
        legal_confirmed_on: compile({ "id" => "confirmed_on_re", "re" => raw.dig("legal_claim", "confirmed_on_re") }, "legal_claim"),
        legal_why: raw.dig("legal_claim", "why"),
        faq_heading: raw.dig("required_sections_ja", "faq_heading"),
        # LinkedIn's own rules (S9). `fetch` on the section, so a file that has
        # lost it fails loudly here instead of turning linkedin_violations into
        # a method that always returns [] — a guard that quietly stopped
        # guarding looks exactly like a guard that found nothing, which is the
        # standing lesson of this file.
        linkedin: {
          forbidden: raw.fetch("linkedin").fetch("forbidden").map { |f| compile(f, "linkedin") },
          limits: raw.fetch("linkedin").fetch("limits")
        }
      }.tap do |r|
        raise RuleFileError, "guard_rules.json carries no forbidden patterns" if r[:forbidden].empty?
        raise RuleFileError, "guard_rules.json carries no linkedin patterns" if r[:linkedin][:forbidden].empty?
      end
    rescue Errno::ENOENT
      raise RuleFileError, "guard_rules.json is missing at #{RULES_PATH}"
    end

    # Compiled EAGERLY, every pattern, every load. A rule written in syntax
    # Ruby cannot parse would otherwise simply never match — and a guard that
    # has silently stopped guarding is indistinguishable from a guard that found
    # nothing. Flags come from fields rather than inline modifiers because `(?i)`
    # is Ruby-only and dotall is `s` in JavaScript but `m` in Ruby; the JSON has
    # to compile in both.
    def compile(rule, where)
      opts = 0
      opts |= Regexp::IGNORECASE if rule["ignorecase"]
      opts |= Regexp::MULTILINE  if rule["dotall"]
      Regexp.new(rule.fetch("re"), opts)
        .then { |re| Rule.new(id: rule["id"], re: re, why: rule["why"]) }
    rescue RegexpError => e
      raise RuleFileError,
            "guard_rules.json: #{where} «#{rule['id'] || rule['re']}» does not compile as a Ruby Regexp: #{e.message}"
    end
  end

  # `surfaces` is a NAMED corpus: { "post_ja.md (body)" => "…", … }. Named
  # rather than concatenated so a violation says which file it is in and adding
  # a surface means adding a key — the concatenated version made the scope
  # invisible and the scope was wrong.
  def initialize(surfaces:, article_ja: nil, article_en: nil, title: nil,
                 tweets: [], linkedin_text: nil, faq: [], summary_ko_missing: [])
    @surfaces = surfaces
    @article_ja = article_ja
    @article_en = article_en
    @title = title
    @tweets = Array(tweets)
    @linkedin_text = linkedin_text
    @faq = Array(faq)
    @summary_ko_missing = Array(summary_ko_missing)
  end

  # { "violations" => [...], "checked_at" => iso8601 }
  # Shaped for `package["guard"]` — plain strings only, because it crosses an
  # ActiveJob serialization boundary on its way into the review email.
  def result
    {
      "violations" => violations,
      "checked_at" => Time.current.iso8601,
      "rules_version" => Digest::SHA256.hexdigest(File.read(RULES_PATH))[0, 12]
    }
  end

  def violations
    @violations ||= [
      forbidden_violations,
      must_line_violations,
      legal_claim_violations,
      length_violations,
      faq_violations,
      linkedin_violations,
      summary_ko_violations
    ].flatten.compact
  end

  private

  def r
    self.class.rules
  end

  def forbidden_violations
    @surfaces.flat_map do |where, text|
      r[:forbidden].filter_map do |rule|
        m = rule.re.match(text.to_s)
        next unless m

        "#{where}: 「#{m[0].to_s.first(40)}」 — #{rule.why} [#{rule.id}]"
      end
    end
  end

  # The required line, checked the way the rule is written: its own line, ending
  # in 「。」. A substring check would pass on a sentence buried mid-paragraph,
  # which is copy rather than the standing instruction the strategy asks for —
  # and all three existing episodes were in exactly that state until this round.
  def must_line_violations
    out = []
    sentence = r[:must_line]["ja_sentence"]
    line = r[:must_line]["ja"]

    if @article_ja.present?
      own_line = @article_ja.to_s.split(/\r?\n/).any? { |l| l.strip.delete("*").strip == sentence }
      if !own_line && @article_ja.to_s.include?(line)
        out << "post_ja.md (body): 「#{sentence}」 が独立した行になっていない(または「。」で終わっていない)"
      elsif !own_line
        out << "post_ja.md (body): 必須文 「#{sentence}」 がない"
      end
    end

    if @article_en.present? && !Regexp.new(Regexp.escape(r[:must_line]["en"]), Regexp::IGNORECASE).match?(@article_en.to_s)
      out << %(post_en.md: missing the English form of the required line ("#{r[:must_line]['en']}"))
    end

    if @tweets.any? && @tweets.none? { |t| t.to_s.include?(line) }
      out << "x_thread: 必須文 「#{line}」 を含むツイートがない"
    end
    out
  end

  # Conditional. IF the article claims what the law requires or restricts, THEN
  # the same article must carry a *.go.jp primary source and the date it was
  # confirmed. No claim → no requirement. Cross-review Q4 was explicit that
  # «every article needs a 施行日» invites a fabricated citation: a 手順 piece
  # about dragging a file onto a page has no statute to cite.
  def legal_claim_violations
    [ [ "post_ja.md", @article_ja ], [ "post_en.md", @article_en ] ].filter_map do |where, article|
      next if article.blank?

      hits = r[:legal_claim_patterns].select { |p| p.re.match?(article.to_s) }
      next if hits.empty?

      has_url  = r[:legal_source_url].re.match?(article.to_s)
      has_date = r[:legal_confirmed_on].re.match?(article.to_s)
      next if has_url && has_date

      missing = []
      missing << "*.go.jp の原文URL" unless has_url
      missing << "「確認日: YYYY-MM-DD」" unless has_date
      "#{where}: 法的主張 (#{hits.map(&:id).join(', ')}) があるのに #{missing.join(' と ')} がない — #{r[:legal_why]}"
    end
  end

  def length_violations
    out = []
    lim = r[:limits]

    if @title.present? && @title.to_s.length > lim["title_chars"]
      out << "title: #{lim['title_chars']}字以内 — 現在 #{@title.to_s.length}字"
    end

    # Both limits are measured in the SAME unit — twitter-text weighted length —
    # because that is the unit strategy v3.1 §3-3 defines them in
    # (「140字(全角2・半角1・URL 23 換算)」). Comparing the editorial limit against a
    # raw character count, which the pipeline did until now, silently doubles
    # the allowance for Japanese: 140 raw CJK characters weigh 280.
    @tweets.each_with_index do |t, i|
      w = self.class.weighted_length(t)
      chars = t.to_s.length
      if w > lim["tweet_weighted"]
        out << "x_thread tweet #{i + 1}: X の上限 #{lim['tweet_weighted']} (weighted) を超えている — weighted #{w} / #{chars}字。投稿できません"
      elsif w > lim["tweet_editorial"]
        # Ours, named as ours. v3 called 140 «X's limit», which cross-review Q3
        # corrected: the platform's cap is 280 weighted and 140 is a house rule.
        out << "x_thread tweet #{i + 1}: 編集上限 #{lim['tweet_editorial']} (weighted) を超えている — weighted #{w} / #{chars}字"
      end
    end

    # The LinkedIn character limit used to be checked HERE as well. Removed in
    # S9 — not relaxed, MOVED: it now lives with the rest of the LinkedIn rules
    # in `linkedin_violations`, under the surface name of the file a person
    # actually edits (linkedin_en.md, not "linkedin_text"). Two checks on one
    # rule produced two lines in the violation list saying the same thing, and
    # the next person to change the number would have found one of them.
    out
  end

  def faq_violations
    want = r[:limits]["faq_questions"]
    return [] if @faq.empty? # no FAQ file at all is reported by the importer, not here
    return [] if @faq.length == want

    [ "faq_ja.md: FAQ は #{want}問 — 現在 #{@faq.length}問" ]
  end

  # ── LinkedIn (S9) ──────────────────────────────────────────────────────────
  #
  # Checked separately from `forbidden` because the rules are about THIS surface
  # and nowhere else. 「sign up」 is fine in a landing page and wrong in a dev
  # log; a 25-word average sentence is fine in the Japanese article and wrong in
  # a post whose whole point is plain English. Folding them into the global
  # forbidden list would either fire everywhere or require a surface condition
  # on each pattern, and the second is the same thing with more places to be
  # inconsistent.
  #
  # The length/shape limits are measured, not regexed: sentence-length average,
  # link count, hashtag count. They say what they measured in the message,
  # because 「문장이 길다」 with no number is not actionable.
  def linkedin_violations
    return [] if @linkedin_text.blank?

    text = @linkedin_text.to_s
    rules = r[:linkedin]
    return [] if rules.blank?

    out = rules[:forbidden].filter_map do |rule|
      m = rule.re.match(text)
      next unless m

      "linkedin_en.md: 「#{m[0].to_s.first(40)}」 — #{rule.why} [#{rule.id}]"
    end

    lim = rules[:limits]

    avg = average_sentence_words(text)
    if lim["avg_sentence_words"] && avg > lim["avg_sentence_words"]
      out << "linkedin_en.md: 1文あたり平均 #{avg.round(1)} 語 — 上限 #{lim['avg_sentence_words']} 語(쉬운 말로 쓴다)"
    end

    links = text.scan(%r{https?://\S+}).uniq
    if lim["links"] && links.length > lim["links"]
      out << "linkedin_en.md: リンクが #{links.length} 本 — #{lim['links']} 本のみ(CTA は1つ): #{links.join(', ')}"
    end

    tags = text.scan(/(?<![\w#])#[\p{Alnum}_]+/)
    if lim["hashtags"] && tags.length > lim["hashtags"]
      out << "linkedin_en.md: ハッシュタグ #{tags.length} 個 — 上限 #{lim['hashtags']} 個: #{tags.join(' ')}"
    end

    if lim["chars"] && text.length > lim["chars"]
      out << "linkedin_en.md: #{lim['chars']}字以内 — 現在 #{text.length}字"
    end
    out
  end

  # Words per sentence, averaged.
  #
  # Sentence split on . ! ? followed by whitespace-or-end. Deliberately crude,
  # and the crudeness is in the safe direction: 「Mr. Tanaka」 or a decimal
  # splits one sentence into two and LOWERS the average, so the measure
  # under-reports rather than failing an author for punctuation. A URL counts as
  # one word (it is one token to a reader) and the bold-Unicode first line
  # counts normally — those characters are letters, not markup.
  def average_sentence_words(text)
    sentences = text.split(/(?<=[.!?])\s+|\n{2,}/).map(&:strip).reject(&:empty?)
    # Hashtag-only and link-only lines are not prose and would drag the average
    # down to nothing. Excluded so the number describes the sentences a reader
    # actually reads.
    prose = sentences.reject { |s| s.match?(/\A(?:#[\p{Alnum}_]+\s*)+\z/) || s.match?(%r{\Ahttps?://\S+\z}) }
    return 0.0 if prose.empty?

    prose.sum { |s| s.split(/\s+/).length }.to_f / prose.length
  end

  # ── the reviewer's Korean copy (S9) ────────────────────────────────────────
  #
  # Completeness only. There is no way to check that a Korean summary is a true
  # summary of a Japanese article with a regex, and pretending otherwise would
  # produce the same false comfort as 「a go.jp URL passed, therefore the claim
  # is sourced」. What CAN be checked is that the seven sections the review
  # screen renders are all there — including 「사람이 판단할 한 가지」, which is
  # the sentence the approver personally stands behind.
  #
  # A missing FILE is not reported here; JpEpisodeSource#validate! refuses the
  # import outright. This fires only on a file that exists and is incomplete.
  def summary_ko_violations
    return [] if @summary_ko_missing.empty?

    [ "summary_ko.md: 섹션 누락 #{@summary_ko_missing.length}건 — #{@summary_ko_missing.map { |h| "「## #{h}」" }.join(', ')}" ]
  end

  # ── twitter-text weighted length ───────────────────────────────────────────
  #
  # X counts weight, not characters: the ranges below weigh 1 and everything
  # else (so all Japanese) weighs 2, and a URL is a flat 23 regardless of its
  # real length. Reimplemented here rather than taking the twitter-text gem
  # because this is the whole of the default configuration that matters for our
  # copy, and the gem would be a production dependency added for one function.
  # The JS loader has the same implementation and the unit tests pin the
  # boundaries (全角 / 半角 / URL / combining emoji) in Ruby.
  #
  # Grapheme clusters, not code points: 👨‍👩‍👧 is one visible character to the
  # author and five code points to naive iteration, and X weighs the cluster.
  URL_RE = %r{https?://\S+}
  URL_WEIGHT = 23
  LIGHT_RANGES = [ 0x0000..0x10ff, 0x2000..0x200d, 0x2010..0x201f, 0x2032..0x2037 ].freeze

  def self.weighted_length(text)
    s = text.to_s
    urls = s.scan(URL_RE)
    rest = s.gsub(URL_RE, "")

    total = urls.length * URL_WEIGHT
    rest.each_grapheme_cluster do |g|
      cps = g.codepoints
      total += (cps.length == 1 && LIGHT_RANGES.any? { |r| r.cover?(cps.first) }) ? 1 : 2
    end
    total
  end
end
