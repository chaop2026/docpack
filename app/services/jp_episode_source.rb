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

  # Files attached as package_assets (the admin preview and XPublishJob's media
  # pick come from here). The hero is carousel_1 and is attached separately.
  ASSET_FILES = %w[carousel_1.png carousel_2.png carousel_3.png demo.gif demo.mp4].freeze

  attr_reader :dir, :topic_row, :ep

  def initialize(dir:, topic_row:, ep:)
    @dir = Pathname(dir)
    @topic_row = topic_row
    @ep = ep
  end

  def validate!
    raise InvalidEpisode, "#{dir}/post_ja.md is missing" unless path("post_ja.md").exist?
    raise InvalidEpisode, "#{dir}/post_ja.md has no frontmatter title" if fm_ja["title"].blank?
    raise InvalidEpisode, "#{dir}/post_ja.md has no body" if body_ja_markdown.blank?
    raise InvalidEpisode, "ep#{ep} has no publish_on in topics.json" if topic_row["publish_on"].blank?
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
  # Assembled from post_en.md to strategy v3.1 §3-3: a bold first-line hook, a
  # blank line, three points, the recipient-instructions line in English, the
  # English blog URL with UTM, and three hashtags. ≤1,300 characters.
  #
  # Assembled rather than written by hand because the shape is fixed and the
  # inputs already exist; NOT auto-shortened if it overflows — JpContentGuard
  # reports the length and a human cuts it, for the same reason over-length
  # tweets are reported rather than truncated.
  LINKEDIN_TAGS = "#privacy #redaction #Japan".freeze

  def linkedin_text
    return nil if fm_en.blank?

    [
      bold_unicode(fm_en["hook"].to_s.strip),
      "",
      *Array(fm_en["bullets"]).map { |b| "— #{b}" },
      "",
      "Check the recipient's own instructions first.",
      "",
      blog_url(:en),
      "",
      LINKEDIN_TAGS
    ].join("\n")
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

  # LinkedIn has no formatting controls, so a "bold" first line is written with
  # the Unicode mathematical-bold block. ASCII letters and digits only —
  # everything else is left alone, because there is no bold form of a Japanese
  # character and substituting a lookalike would be worse than plain text.
  def bold_unicode(text)
    text.each_char.map do |c|
      case c
      when "A".."Z" then [ 0x1D400 + (c.ord - 65) ].pack("U")
      when "a".."z" then [ 0x1D41A + (c.ord - 97) ].pack("U")
      when "0".."9" then [ 0x1D7CE + (c.ord - 48) ].pack("U")
      else c
      end
    end.join
  end
end
