# Everything one `content/jp/epNN/` folder says, read once and validated.
#
# Kept separate from the importer so the two questions stay separate: "what do
# the files say" and "what should the database become". It also makes the
# content hash meaningful — it is computed from this object, so two imports of
# the same bytes produce the same hash no matter what the row looks like.
class JpEpisodeSource
  class InvalidEpisode < StandardError; end

  LANDING_PATH = {
    "nyusatsu" => "/safe/jp/nyusatsu/",
    "honnin"   => "/safe/jp/honnin-kakunin/",
    "aimae"    => "/safe/jp/ai-mae/"
  }.freeze

  # Files attached as package_assets (the admin preview, the review mail's
  # attachments and XPublishJob's media pick all come from here). The hero is
  # carousel_1 and is attached separately.
  #
  # guide_en.pdf (S9) is the LinkedIn document post. It is attached here so the
  # review mail can send it — opening the admin, finding the asset list and
  # downloading it is three steps that each have to succeed, on a Saturday,
  # from a phone.
  #
  # ORDER MATTERS, and only accidentally: XPublishJob's media fallback used to
  # take package_assets.first. The PDF is last here, so that fallback would
  # still have found an image — but relying on list order to keep a PDF off a
  # tweet is not a guarantee, so that method now filters by content type and
  # this comment is the only thing order is still doing.
  ASSET_FILES = %w[carousel_1.png carousel_2.png carousel_3.png demo.gif demo.mp4 guide_en.pdf].freeze

  attr_reader :dir, :topic_row, :ep

  def initialize(dir:, topic_row:, ep:)
    @dir = Pathname(dir)
    @topic_row = topic_row
    @ep = ep
  end

  # Checked BEFORE anything is written, and distinct from the content guard.
  #
  # The two answer different questions, and conflating them hides one of them:
  #
  #   validate!            — is there an episode here at all? A missing title or
  #                          an empty body is not a package with a problem, it
  #                          is not a package. Import REFUSES (exit 1).
  #   JpContentGuard       — does this episode follow the writing rules? It is
  #                          imported either way; a violation disables the
  #                          approval button (exit 0).
  #
  # Cross-review Q2: a blank title_ja used to pass straight through, because a
  # JP post is created as a `draft` and the published-post invariant does not
  # apply to drafts. The row was then unapprovable for a reason nothing stated.
  def validate!
    raise InvalidEpisode, "#{dir}/post_ja.md is missing" unless path("post_ja.md").exist?
    raise InvalidEpisode, "#{dir}/post_ja.md has no frontmatter title" if fm_ja["title"].blank?
    raise InvalidEpisode, "#{dir}/post_ja.md has no body" if body_ja_markdown.blank?
    raise InvalidEpisode, "ep#{ep} has no publish_on in topics.json" if topic_row["publish_on"].blank?

    # The resolved values, not just the raw file. `title_ja` prefers
    # topics.json's blog_title_ja, and the rendered body can come out empty
    # from a file that is not empty (frontmatter only, or markdown that renders
    # to nothing) — so the check has to be on what would actually be stored.
    raise InvalidEpisode, "ep#{ep} resolves to a blank title_ja" if title_ja.blank?
    if body_ja_html.blank? || body_ja_html.gsub(/<[^>]*>/, "").strip.empty?
      raise InvalidEpisode, "ep#{ep} body_ja renders to no prose (#{body_ja_html.to_s.length} bytes of markup)"
    end
    raise InvalidEpisode, "#{dir}/x_thread.md has no tweets — run make_episode.mjs #{ep}" if x_thread.empty?

    # ── S9: two inputs that are no longer derivable ──────────────────────────
    #
    # Both were produced by the pipeline before and both are now written by a
    # human, so their absence is the SAME KIND of fact as a missing post_ja.md.
    # They refuse here rather than reporting a guard violation, because a guard
    # violation still imports — and importing a package with a templated
    # LinkedIn post or no Korean summary would hand the reviewer a screen that
    # looks complete.
    unless path("linkedin_en.md").exist?
      raise InvalidEpisode,
            "#{dir}/linkedin_en.md is missing — the LinkedIn post is a dev log written by hand " \
            "(strategy v3.1 §3-3, revised 2026-10-25); it is no longer assembled from post_en.md"
    end
    if linkedin_text.blank?
      raise InvalidEpisode, "#{dir}/linkedin_en.md is empty"
    end

    unless path("summary_ko.md").exist?
      raise InvalidEpisode,
            "#{dir}/summary_ko.md is missing — 승인자가 읽을 수 없는 패키지는 만들지 않는다. " \
            "Write the Korean reviewer's copy (#{SUMMARY_SECTIONS.keys.map { |h| "## #{h}" }.join(' / ')})"
    end
    if summary_ko.blank?
      raise InvalidEpisode,
            "#{dir}/summary_ko.md carries none of the expected sections " \
            "(#{SUMMARY_SECTIONS.keys.join(' / ')}) — check the 「## 」 headings"
    end

    true
  end

  def epp
    format("%02d", ep)
  end

  # ── prose ──────────────────────────────────────────────────────────────────

  def title_ja
    # The BLOG title (search-intent form, v3.1 §4) when topics.json carries one;
    # the frontmatter title is the X/carousel headline and is shorter. Falling
    # back to the frontmatter means an episode written before the §4 table still
    # imports rather than failing on a missing key.
    topic_row["blog_title_ja"].presence || fm_ja["title"]
  end

  def subtitle_ja
    fm_ja["hook"]
  end

  def meta_description_ja
    # The hook, trimmed to a length a SERP will actually show. Not the first
    # paragraph: that opens with context rather than with the answer.
    fm_ja["hook"].to_s.strip.first(120)
  end

  def body_ja_html
    JpMarkdown.render(body_ja_markdown)
  end

  def body_en_html
    return nil if body_en_markdown.blank?

    JpMarkdown.render(body_en_markdown)
  end

  def title_en
    fm_en["title"].presence || topic_row["title_en"]
  end

  def meta_description_en
    fm_en["hook"].to_s.strip.first(160).presence
  end

  def body_ja_markdown
    @body_ja_markdown ||= split_frontmatter(read("post_ja.md")).last
  end

  def body_en_markdown
    @body_en_markdown ||= path("post_en.md").exist? ? split_frontmatter(read("post_en.md")).last : nil
  end

  def fm_ja
    @fm_ja ||= parse_frontmatter(split_frontmatter(read("post_ja.md")).first)
  end

  def fm_en
    @fm_en ||= path("post_en.md").exist? ? parse_frontmatter(split_frontmatter(read("post_en.md")).first) : {}
  end

  # ── derived surfaces ───────────────────────────────────────────────────────

  # [{ "q" =>, "a" => }, …] from faq_ja.md (## question / paragraph answer).
  # [] when the file is absent — stated rather than invented. The FAQPage JSON-LD
  # and the on-page FAQ section are both suppressed on an empty list.
  def faq
    @faq ||= begin
      f = path("faq_ja.md")
      entries = []
      if f.exist?
        f.read.split(/^##\s+/).drop(1).each do |chunk|
          lines = chunk.split("\n")
          q = lines.shift.to_s.strip
          a = lines.join("\n").strip.gsub(/\n{2,}/, "\n")
          entries << { "q" => q, "a" => a } if q.present? && a.present?
        end
      end
      entries
    end
  end

  # The tweets, read out of the GENERATED x_thread.md rather than rebuilt here.
  # make_episode.mjs owns the thread's composition (including appending the
  # required line and splitting it into its own tweet when the CTA would
  # overflow); re-deriving it would give the server a second, silently diverging
  # implementation of the same rule.
  def x_thread
    @x_thread ||= begin
      f = path("x_thread.md")
      f.exist? ? f.read.scan(/^```\n(.*?)\n```/m).flatten.map(&:strip).reject(&:empty?) : []
    end
  end

  # The last tweet of the thread is an English reply (strategy v3.1 §3-3).
  #
  # Written by the author in post_en.md's frontmatter as `x_reply:` when it
  # matters, because it is a tweet and tweets are written, not derived. The
  # fallback is the SHORTEST honest assembly — the CTA and the link — rather
  # than hook + CTA + link: measured, that longer form came out at 168–189
  # weighted for ep01–03, over the 140 editorial limit on all three. Falling
  # back to something that always violates would make the guard fire on every
  # episode forever, which teaches the reader to ignore it.
  #
  # Note it is NOT truncated to fit. Same rule as the thread itself: a sentence
  # cut at a byte boundary is a sentence the author did not write, and it is
  # invisible once posted.
  def x_reply_en
    return nil if fm_en.blank?
    return fm_en["x_reply"] if fm_en["x_reply"].present?

    "#{fm_en['cta']}\n#{utm_url('x')}".presence
  end

  # ── LinkedIn ───────────────────────────────────────────────────────────────
  #
  # READ FROM linkedin_en.md, verbatim. Not assembled.
  #
  # Strategy v3.1 §3-3 was revised on 2026-10-25 and the revised row is the
  # specification for this method, quoted in full because the change is a
  # change of KIND, not of shape:
  #
  #   | LinkedIn | **개발 일지(dev log)** — Justin 1인칭 EN. 「이번 주 내가 무엇을
  #   만들었고 왜 그렇게 설계했는지」가 본문이고, SafeFile은 그 작업의 맥락으로만
  #   등장. 구조: 첫 줄 = 이번 주 한 일 한 문장(유니코드 볼드) → 설계 결정·배운 것
  #   2~3포인트(기술적 구체성: 어떤 문제를 어떻게 풀었나) → 「이런 걸 서비스하고
  #   있다, 궁금하면 한 번 써보고 피드백 달라」 1문장 → 링크 1개(블로그 EN 또는
  #   랜딩) → 해시태그 3개(#buildinpublic #privacy #rails 류). **금지**: 일본인
  #   대상 광고처럼 읽히는 문장(「日本の入札で…」식 타깃 호소), 기능 나열·세일즈 톤,
  #   브랜드 화법(「SafeFile helps you…」), CTA 2개 이상 | ≤1,300자 | 전문성을
  #   보여주는 곳이지 홍보하는 곳이 아님(Justin 2026-10-25) |
  #
  # ── Why the assembly had to go, not just be adjusted ───────────────────────
  #
  # The old version built the post out of post_en.md's `hook` and `bullets` plus
  # a fixed CTA line and fixed hashtags. That produces a competent summary of the
  # ARTICLE, and the article is addressed to a Japanese person who has to submit
  # a document. The LinkedIn audience is not that person. A dev log is a first-
  # person account of a design decision — what the author tried, what broke,
  # what he now believes — and there is no arrangement of an article's bullet
  # points that becomes one. Keeping the assembly and bolting rules on top would
  # have let the pipeline keep producing copy nobody wrote, which is the thing
  # the strategy revision is about.
  #
  # So: missing file → the import REFUSES (see validate!). That is deliberately
  # the input-missing answer rather than a guard violation — there is nothing to
  # review, and a package whose LinkedIn post was invented by a template is not
  # an incomplete package, it is a wrong one.
  def linkedin_text
    @linkedin_text ||= path("linkedin_en.md").exist? ? read("linkedin_en.md").strip : nil
  end

  # ── Korean summary (S9) ────────────────────────────────────────────────────
  #
  # The approver reads Korean. The package is Japanese.
  #
  # Everything else in this pipeline is JA-primary by design (strategy v3.1 §3-3:
  # 「KO 본문은 쓰지 않는다」) and that stays true — this is not a Korean edition,
  # it is the reviewer's copy. Without it the weekly 「承認」 button asks somebody
  # to take responsibility for 2,000 characters of Japanese legal prose, and the
  # honest thing a person does in that position is approve it anyway.
  #
  # Seven sections, fixed, in a file with no frontmatter. The headings are
  # Korean because the file is written and read in Korean; the keys are ASCII
  # because the views and tests index by them. THIS CONSTANT IS THE ONLY PLACE
  # THE TWO ARE TIED TOGETHER.
  SUMMARY_SECTIONS = {
    "제목" => "title",
    "요지" => "gist",
    "표" => "table",
    "근거" => "basis",
    "트윗" => "tweets",
    "FAQ" => "faq",
    "사람이 판단할 한 가지" => "judgment"
  }.freeze

  # Sections rendered next to a numbered JA original (tweet 3's Korean goes
  # under tweet 3), so they are parsed into arrays rather than kept as prose.
  SUMMARY_LIST_SECTIONS = %w[tweets faq].freeze

  # { "title" => "…", "tweets" => ["…", …], … } — or nil when the file is absent.
  #
  # nil rather than {} on purpose: `{}` is a summary with no sections and would
  # flow into the guard as seven separate violations, which describes a file
  # somebody wrote badly. There is no file. validate! says so and the import
  # stops.
  def summary_ko
    return @summary_ko if defined?(@summary_ko)

    @summary_ko = path("summary_ko.md").exist? ? parse_summary(read("summary_ko.md")) : nil
  end

  def summary_ko_present?
    summary_ko.present?
  end

  # The sections SUMMARY_SECTIONS names that this file does not actually carry
  # (missing, or present as an empty heading). Reported by JpContentGuard, which
  # is the right half of the split: the file exists and somebody wrote it, so
  # this is a rule violation to fix rather than a missing input.
  def summary_ko_missing_sections
    return SUMMARY_SECTIONS.keys if summary_ko.nil?

    SUMMARY_SECTIONS.filter_map do |heading, key|
      value = summary_ko[key]
      heading if value.blank? || (value.is_a?(Array) && value.all?(&:blank?))
    end
  end

  # ── assets ─────────────────────────────────────────────────────────────────

  def hero_path
    p = path("carousel_1.png")
    p.exist? ? p : nil
  end

  def asset_paths
    ASSET_FILES.map { |n| path(n) }.select(&:exist?)
  end

  def media_for_first_tweet
    [ path("demo.gif"), path("carousel_1.png") ].find(&:exist?)
  end

  # ── identity ─────────────────────────────────────────────────────────────── #

  # Slug: assigned once, at creation, and never again (Post validates that).
  # Derived from title_en rather than from the Japanese title so the URL is
  # ASCII, and prefixed with the episode number so it is stable even if the
  # English headline is reworded before first import.
  def slug
    base = topic_row["title_en"].to_s.parameterize.first(40).sub(/-\z/, "")
    base = "ep#{epp}" if base.blank?
    "jp-ep#{epp}-#{base}"
  end

  def landing_path
    LANDING_PATH.fetch(topic_row["landing"], "/safe/jp/nyusatsu/")
  end

  def utm_url(source)
    "#{base_url}#{landing_path}?utm_source=#{source}&utm_medium=#{source == 'blog' ? 'organic' : 'social'}&utm_campaign=ep#{epp}"
  end

  def blog_url(locale)
    prefix = locale.to_sym == :ja ? "/ja" : "/#{locale}"
    "#{base_url}#{prefix}/blog/#{slug}?utm_source=linkedin&utm_medium=social&utm_campaign=ep#{epp}"
  end

  def utm
    {
      "blog" => utm_url("blog"),
      "x" => utm_url("x"),
      "linkedin" => blog_url(:en)
    }
  end

  def manifest
    @manifest ||= path("manifest.json").exist? ? (JSON.parse(read("manifest.json")) rescue {}) : {}
  end

  # A fingerprint of everything that would be published. Two imports of the same
  # bytes give the same hash, which is what makes an import_conflict report
  # legible: it says WHICH version on disk was refused.
  def content_hash
    @content_hash ||= Digest::SHA256.hexdigest([
      title_ja, subtitle_ja, body_ja_markdown, body_en_markdown.to_s,
      faq.to_json, x_thread.to_json, linkedin_text.to_s,
      # S9. Both are now files a human edits, so both have to move the hash —
      # otherwise `unchanged?` reports "nothing on disk changed" and a rewritten
      # Korean summary never reaches the review screen. (That is not
      # hypothetical: the hash is what the importer compares, and it returns
      # without writing a single column when it matches.)
      summary_ko.to_json,
      asset_paths.map { |p| "#{p.basename}:#{p.size}" }.join(",")
    ].join("\x00"))
  end

  def captions
    Array(fm_ja["captions"])
  end

  private

  def base_url
    ENV.fetch("BASE_URL", "https://slimfile.net")
  end

  def path(name)
    dir.join(name)
  end

  def read(name)
    path(name).read
  end

  def split_frontmatter(text)
    return [ "", text ] unless text.start_with?("---")

    close = text.index("\n---", 3)
    return [ "", text ] unless close

    [ text[3...close], text[(text.index("\n", close + 1) || close) + 1..].to_s ]
  end

  # The same deliberately small YAML subset make_episode.mjs parses: `key: value`
  # and `key:` followed by `- ` items. A real YAML parser would accept shapes the
  # rest of the pipeline does not read.
  def parse_frontmatter(head)
    data = {}
    list_key = nil
    head.to_s.split("\n").each do |raw|
      line = raw.rstrip
      next if line.strip.empty? || line.strip.start_with?("#")

      if (item = line.match(/\A\s*-\s+(.*)\z/)) && list_key
        data[list_key] << unquote(item[1])
        next
      end
      kv = line.match(/\A([A-Za-z_][\w-]*):\s*(.*)\z/)
      raise InvalidEpisode, "frontmatter line not understood: #{line}" unless kv

      key, value = kv[1], kv[2]
      if value.strip.empty?
        list_key = key
        data[key] = []
      else
        list_key = nil
        data[key] = unquote(value)
      end
    end
    data
  end

  def unquote(s)
    s.to_s.strip.sub(/\A"(.*)"\z/m, '\1').sub(/\A'(.*)'\z/m, '\1')
  end

  # summary_ko.md → { key => text | [texts] }.
  #
  # Only the headings SUMMARY_SECTIONS names are kept. An unrecognised 「## …」 is
  # DROPPED rather than carried through under its own name: the review screen
  # renders fixed slots, so a section it does not know about would be written,
  # stored, and never shown to anybody — a silent loss. Dropping it means the
  # guard then reports the heading it was supposed to be as missing, and the
  # author sees a typo'd heading as a named violation.
  def parse_summary(text)
    out = {}
    text.split(/^##[ \t]+/).drop(1).each do |chunk|
      lines = chunk.split("\n")
      heading = lines.shift.to_s.strip
      key = SUMMARY_SECTIONS[heading]
      next unless key

      body = lines.join("\n").strip
      out[key] = SUMMARY_LIST_SECTIONS.include?(key) ? split_numbered(body) : body
    end
    out
  end

  # "1. …\n2. …" → ["…", "…"], with continuation lines kept on their item.
  #
  # Numbered because the items line up with numbered originals (tweet N, FAQ N)
  # and the review screen puts each one under its own JA source. A blank-line
  # split would look simpler and would silently renumber everything the moment
  # an item ran to two paragraphs.
  #
  # Items are returned in FILE ORDER, not sorted by the number written in the
  # file. If the author numbers them 1,3,2 the screen shows them 1,3,2 and the
  # mismatch is visible; re-sorting would hide a real editing mistake and pair
  # Korean text with the wrong Japanese tweet.
  def split_numbered(body)
    items = []
    body.to_s.split("\n").each do |line|
      if (m = line.match(/\A\s*(\d+)[.)]\s*(.*)\z/))
        items << m[2].to_s.strip
      elsif items.any? && line.strip.present?
        items[-1] = "#{items[-1]}\n#{line.strip}"
      end
    end
    # No numbered items at all → the whole block is one item. The author wrote
    # prose where a list was asked for; keeping the text is better than
    # reporting the section empty, because the text is what the reviewer needs.
    items.presence || [ body.to_s.strip ].reject(&:empty?)
  end

  # `bold_unicode` lived here and is DELETED (S9), not left in place.
  #
  # It mapped ASCII into the Unicode mathematical-bold block so the assembled
  # LinkedIn post could have a "bold" first line. linkedin_en.md now carries
  # those characters directly — the author types the bold line — so the method
  # had no callers. Leaving an unused helper that turns prose into a LinkedIn
  # hook is an invitation to re-assemble the post from frontmatter, which is the
  # behaviour this round removed on purpose. Same reasoning that deleted
  # Post#translated_locales once indexable_locales replaced it.
end
