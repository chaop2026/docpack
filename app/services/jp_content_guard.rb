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
# blocks the 「承認」 button and is listed in red at the top of the review email;
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
        faq_heading: raw.dig("required_sections_ja", "faq_heading")
      }.tap do |r|
        raise RuleFileError, "guard_rules.json carries no forbidden patterns" if r[:forbidden].empty?
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
                 tweets: [], linkedin_text: nil, faq: [])
    @surfaces = surfaces
    @article_ja = article_ja
    @article_en = article_en
    @title = title
    @tweets = Array(tweets)
    @linkedin_text = linkedin_text
    @faq = Array(faq)
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
      faq_violations
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

    if @linkedin_text.present? && @linkedin_text.to_s.length > lim["linkedin_chars"]
      out << "linkedin_text: #{lim['linkedin_chars']}字以内 — 現在 #{@linkedin_text.to_s.length}字"
    end
    out
  end

  def faq_violations
    want = r[:limits]["faq_questions"]
    return [] if @faq.empty? # no FAQ file at all is reported by the importer, not here
    return [] if @faq.length == want

    [ "faq_ja.md: FAQ は #{want}問 — 現在 #{@faq.length}問" ]
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
