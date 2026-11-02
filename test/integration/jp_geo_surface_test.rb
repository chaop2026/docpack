require "test_helper"

# S11 — the surfaces an answer engine and a crawler actually read.
#
# The problem this round is answering was measured, not guessed
# (docs/jp/seo_geo_audit_2026-11-02.md): every SafeFile JP page was sitting in
# Search Console as "Discovered – currently not indexed", llms.txt did not
# mention SafeFile at all, two of the three landing pages had no question-shaped
# unit for an engine to quote, and nothing already indexed linked to any of them.
#
# Three things are covered here, and each one is checked in BOTH directions
# where there is a direction to check — "the JP track gained X" is only half of
# the requirement; "the Korean track did not" is the other half, and it is the
# half that silently fails.
#
#   1. llms.txt carries a SafeFile (JP) section, and that section obeys the same
#      forbidden-phrase rules the episodes do.
#   2. /ja/blog describes itself as the Japanese publication it is, with a
#      CollectionPage; /blog is untouched.
#   3. A Japanese article carries publisher.logo and a BreadcrumbList; a Korean
#      article carries neither. (E-1 cannot see JSON-LD — a snapshot that cannot
#      see a field cannot protect it.)
#   4. The three landing pages are linked from pages that are already indexed.
class JpGeoSurfaceTest < ActionDispatch::IntegrationTest
  LANDING_PATHS = %w[/safe/jp/nyusatsu/ /safe/jp/honnin-kakunin/ /safe/jp/ai-mae/].freeze

  def utf8_body
    response.body.dup.force_encoding("UTF-8")
  end

  def ld_blocks(html)
    html.scan(%r{<script type="application/ld\+json">(.*?)</script>}m).map do |(raw)|
      JSON.parse(raw)
    rescue JSON::ParserError => e
      flunk "a JSON-LD block does not parse: #{e.message}\n#{raw.to_s.first(300)}"
    end
  end

  # The forbidden list from the single rules file both content engines read.
  # Reused rather than restated: a second copy of these patterns is how the two
  # would come to disagree, which is the whole reason guard_rules.json exists.
  def forbidden_rules
    JSON.parse(Rails.root.join("content", "jp", "guard_rules.json").read).fetch("forbidden").map do |f|
      opts = 0
      opts |= Regexp::IGNORECASE if f["ignorecase"]
      opts |= Regexp::MULTILINE  if f["dotall"]
      [ f["id"], Regexp.new(f.fetch("re"), opts), f["why"] ]
    end
  end

  # ── 1. llms.txt ───────────────────────────────────────────────────────────

  def jp_section
    get "/llms.txt"
    assert_response :success
    body = utf8_body
    i = body.index("## SafeFile (JP)")
    assert i, "llms.txt has no «## SafeFile (JP)» section — an AI asked about SafeFile JP has nothing to read"
    j = body.index(/^## /, i + 1) || body.length
    body[i...j]
  end

  test "llms.txt describes SafeFile JP in Japanese and English" do
    s = jp_section
    assert_operator s.length, :>, 800, "the section is too short to be describing a product"

    # The four document types the tool actually classifies. Asserted by name
    # because this is the one place an answer engine learns the SCOPE, and a
    # scope that drifts wider than the code is a false claim about the product.
    %w[資格確認書 運転免許証 マイナンバーカード 住民票].each do |doc|
      assert_includes s, doc, "llms.txt does not name #{doc}"
    end
    # The four purposes, by their Japanese names.
    %w[本人確認提出 個人番号手続 入札添付 相談用共有].each do |p|
      assert_includes s, p, "llms.txt does not name the #{p} purpose"
    end

    assert_includes s, "サーバーには送信されません", "the files-stay-local claim is missing"
    assert_includes s, "登録", "the no-signup claim is missing"
    assert_includes s, "提出先の指示を必ず確認してください", "the standing instruction is missing"

    # The limit, not just the capability. A section that lists only what works
    # is what makes an engine assert the tool handles documents it does not.
    assert_includes s, "限界", "the Japanese half states no limitation"
    assert_match(/^- Limits:/m, s, "the English half states no limitation")
    assert_includes s, "範囲", "the manual-area-selection fallback is not mentioned"

    # Both halves present.
    assert_includes s, "### 日本語"
    assert_includes s, "### English"
    assert_includes s, "SafeFile is a browser tool"
  end

  test "llms.txt lists every page and channel" do
    s = jp_section
    [
      "https://slimfile.net/safe/jp/nyusatsu/",
      "https://slimfile.net/safe/jp/honnin-kakunin/",
      "https://slimfile.net/safe/jp/ai-mae/",
      "https://slimfile.net/safe/",
      "https://slimfile.net/ja/blog",
      "https://www.youtube.com/channel/UC0TZjC4xG0iaRVqFrJroJxA",
      "https://x.com/safefile_jp",
      "https://lin.ee/rV1LpPB"
    ].each { |url| assert_includes s, url, "llms.txt is missing #{url}" }
  end

  test "the llms.txt JP section passes the content guard's forbidden list" do
    # S11 asked for this explicitly, and it is not ceremony: llms.txt is the
    # file an answer engine quotes verbatim, so an overclaim here ("防ぐ",
    # "絶対", "一括") is repeated by a machine to people who never saw the page.
    s = jp_section
    hits = forbidden_rules.filter_map do |id, re, why|
      m = re.match(s)
      "«#{m[0]}» [#{id}] — #{why}" if m
    end
    assert_empty hits, "llms.txt's SafeFile (JP) section breaks the content rules:\n  #{hits.join("\n  ")}"
  end

  # The two passages on /safe/jp/nyusatsu/ that describe the Team plan ROADMAP,
  # and the sentence each one must carry to be allowed to.
  #
  # ⚠️ They are excluded from the check below, and the exclusion is the
  # interesting part. The forbidden list means "do not advertise a feature that
  # has not shipped", and 「複数PDFの一括処理」/「処理記録」/"batch PDF processing"
  # are exactly that — except that this page says, in the same breath, that
  # they have not shipped (「※ 以下の機能はパイロット期間中に順次提供します（現在は
  # 1ファイルずつ処理）」, added in S6b for this reason). A disclosed roadmap is a
  # different act from a claim.
  #
  # So rather than narrow the rules or narrow the page, the two passages are cut
  # out AND their disclaimers are asserted to still be there. The exclusion
  # cannot be used to hide an undisclosed roadmap: delete the disclaimer and
  # this test fails.
  ROADMAP_BLOCKS = [
    [ %r{<section[^>]*id="team".*?</section>}m,
      "\u203b \u4ee5\u4e0b\u306e\u6a5f\u80fd\u306f\u30d1\u30a4\u30ed\u30c3\u30c8\u671f\u9593\u4e2d\u306b\u9806\u6b21\u63d0\u4f9b\u3057\u307e\u3059\uff08\u73fe\u5728\u306f1\u30d5\u30a1\u30a4\u30eb\u305a\u3064\u51e6\u7406\uff09" ],
    [ %r{<p><strong>Team plan</strong>.*?</p>}m,
      "These arrive progressively during the pilot; today the tool processes one file at a time." ]
  ].freeze

  test "the landing pages' visible text passes the same forbidden list" do
    # Same rules, applied to the pages themselves. Comments and <style> are
    # stripped; <script type=application/ld+json> is NOT, because Google quotes
    # it \u2014 so an overclaim living only in structured data would still be an
    # overclaim shown to readers.
    #
    # Comments are stripped for a concrete reason: the nyusatsu page's own
    # comment quotes the \u5148\u775010\u793e line it replaced, in order to record why.
    rules = forbidden_rules
    checked = 0

    LANDING_PATHS.each do |path|
      get path
      assert_response :success
      raw = utf8_body

      html = raw
             .gsub(/<!--.*?-->/m, "")
             .gsub(%r{<style.*?</style>}m, "")
             .gsub(%r{<script(?![^>]*application/ld\+json).*?</script>}m, "")

      ROADMAP_BLOCKS.each do |pattern, disclaimer|
        next unless html.match?(pattern)

        assert_includes raw, disclaimer,
                        "#{path}: a roadmap passage is being excluded from the content rules " \
                        "but no longer says the features have not shipped"
        html = html.gsub(pattern, " ")
      end

      text = html.gsub(/<[^>]+>/, " ")
      checked += text.length

      hits = rules.filter_map do |id, re, why|
        m = re.match(text)
        "#{path}: \u00ab#{m[0]}\u00bb [#{id}] \u2014 #{why}" if m
      end
      assert_empty hits, hits.join("\n  ")
    end

    # Vacuity guard. Three pages that stripped down to nothing would pass the
    # loop above without a single pattern having been given anything to match \u2014
    # the shape of the canonical_sweep failure this repository already shipped.
    assert_operator checked, :>, 6_000,
                    "only #{checked} characters of landing text were checked; the stripping is eating the pages"
  end

  # ── 2. /ja/blog ───────────────────────────────────────────────────────────

  test "/ja/blog titles and describes itself as the Japanese publication" do
    get "/ja/blog"
    assert_response :success
    html = utf8_body

    assert_select "title", text: I18n.t("blog.jp.title", locale: :ja)
    assert_select %(meta[name="description"]) do |els|
      assert_equal I18n.t("blog.jp.meta_description", locale: :ja), els.first["content"]
    end
    # Not the Korean blog's subject. This is the assertion that would have
    # caught the live state: /ja/blog was advertising 「画像圧縮、PDF変換、
    # ファイル最適化」 while serving SafeFile JP articles.
    refute_includes html, I18n.t("blog.meta_description", locale: :ja)
    assert_select "h1", text: I18n.t("blog.jp.heading", locale: :ja)
  end

  test "/ja/blog carries a CollectionPage listing the posts it renders" do
    post = create_jp_post(ep: 81, slug: "jp-ep81-geo-collection")
    get "/ja/blog"
    assert_response :success

    cp = ld_blocks(utf8_body).find { |b| b["@type"] == "CollectionPage" }
    assert cp, "/ja/blog has no CollectionPage block"
    assert_equal "ja", cp["inLanguage"]
    assert_equal "https://slimfile.net/ja/blog", cp["url"]
    assert_equal "https://slimfile.net/safe/brand/icon-512.png", cp.dig("publisher", "logo", "url")

    items = cp.dig("mainEntity", "itemListElement")
    assert_equal cp.dig("mainEntity", "numberOfItems"), items.length,
                 "numberOfItems disagrees with the list it is counting"
    urls = items.map { |i| i["url"] }
    assert_includes urls, "https://slimfile.net/ja/blog/#{post.slug}"
    assert_equal (1..items.length).to_a, items.map { |i| i["position"] },
                 "positions must be 1..n with no gaps"

    # The markup must not describe entries the page does not show. Every listed
    # URL has to correspond to a card actually rendered.
    urls.each do |u|
      assert_select %(a[href="#{URI.parse(u).path}"]), { minimum: 1 },
                    "the CollectionPage lists #{u} but no card links to it"
    end
  end

  test "/blog gets no CollectionPage and keeps its own title" do
    # The other half. A CollectionPage on the Korean listing would be a change
    # to a page this round is not touching, and the Japanese strings must not
    # leak into it.
    get "/blog"
    assert_response :success
    html = utf8_body

    assert_nil ld_blocks(html).find { |b| b["@type"] == "CollectionPage" },
               "the Korean listing gained a CollectionPage"
    assert_select "title", text: I18n.t("blog.title", locale: :ko)
    refute_includes html, I18n.t("blog.jp.heading", locale: :ja)
    refute_includes html, "jp-landing-card"
  end

  test "/blog read with a Japanese cookie is still the Korean listing" do
    # url_locale, not I18n.locale. Keying this on the negotiated locale would
    # make /blog answer with the Japanese blog's title to anyone whose cookie
    # said ja — a second URL for the Japanese publication, which is the
    # duplicate shape this repository has been penalised for twice.
    get "/ja/faq" # persists the locale cookie
    get "/blog"
    assert_response :success
    assert_select "title", { text: I18n.t("blog.title", locale: :ja) },
                  "the Korean listing's title should be the KOREAN blog's, translated"
    refute_includes utf8_body, I18n.t("blog.jp.title", locale: :ja)
  end

  test "the two listings are not advertised as translations of each other" do
    # They used to be. The layout emits all four UI locales unless a controller
    # narrows the set, so /ja/blog declared /blog as its Korean alternate and
    # /blog declared /ja/blog as its Japanese one — while the two serve
    # DIFFERENT POSTS. Google's rule is that an hreflang target is the same
    # document in another language, and this is the signal shape that has
    # already cost this repository twice (/safe/, /en/about).
    get "/ja/blog"
    assert_response :success
    assert_select "head link[rel=alternate][hreflang]", 0,
                  "/ja/blog is one Japanese document; it has no language alternates"
    assert_select "head link[rel=alternate][hreflang=x-default]", 0,
                  "an x-default pointing at the Korean blog would say «if your language is " \
                  "not listed, read this» about a different publication"

    get "/blog"
    assert_response :success
    langs = utf8_body.scan(%r{<link[^>]+rel="alternate"[^>]+hreflang="([^"]+)"}).flatten.sort
    assert_equal %w[en es ko x-default], langs,
                 "the Korean listing's alternates are the three that really are translations of it"
  end

  test "the sitemap says the same thing the pages say about the listings" do
    # A page and a sitemap disagreeing about hreflang is its own documented
    # failure here (the ?category= entries, 2026-09-17). Both halves checked
    # from the rendered XML.
    get "/sitemap.xml"
    assert_response :success
    xml = utf8_body

    ja_entry = xml[%r{<url>\s*<loc>https://slimfile\.net/ja/blog</loc>.*?</url>}m]
    assert ja_entry, "/ja/blog is not in the sitemap"
    refute_includes ja_entry, "hreflang", "/ja/blog's sitemap entry declares alternates"

    ko_entry = xml[%r{<url>\s*<loc>https://slimfile\.net/blog</loc>.*?</url>}m]
    assert ko_entry
    assert_includes ko_entry, %(hreflang="en")
    assert_includes ko_entry, %(hreflang="es")
    refute_includes ko_entry, %(hreflang="ja"),
                    "the Korean listing still cross-references the Japanese publication"
  end

  # ── 3. article structured data ────────────────────────────────────────────

  test "a Japanese article carries publisher.logo and a BreadcrumbList" do
    post = create_jp_post(ep: 82, slug: "jp-ep82-geo-article")
    get "/ja/blog/#{post.slug}"
    assert_response :success
    blocks = ld_blocks(utf8_body)

    article = blocks.find { |b| b["@type"] == "Article" }
    assert article, "no Article block"
    assert_equal "https://slimfile.net/safe/brand/icon-512.png",
                 article.dig("publisher", "logo", "url"),
                 "Google's Article rich result documents publisher.logo as required"

    # S11b (2026-11-02 Justin decision). S11 shipped the SafeFile logo under the
    # name "SlimFile", so one entity was described under two names across the
    # articles and the landings' Organization block. Asserted as the whole hash:
    # a check on `name` alone would stay green if the logo or url were lost.
    assert_equal({ "@type" => "Organization",
                   "name" => "SafeFile",
                   "url" => "https://slimfile.net",
                   "logo" => { "@type" => "ImageObject",
                               "url" => "https://slimfile.net/safe/brand/icon-512.png" } },
                 article["publisher"],
                 "the JP track's publisher is SafeFile, matching the landings' Organization")

    bc = blocks.find { |b| b["@type"] == "BreadcrumbList" }
    assert bc, "no BreadcrumbList block"
    assert_equal [ "ホーム", "ブログ", post.title(:ja) ],
                 bc["itemListElement"].map { |i| i["name"] }
    assert_equal [ "https://slimfile.net/ja", "https://slimfile.net/ja/blog", nil ],
                 bc["itemListElement"].map { |i| i["item"] },
                 "the last rung is the current page and must carry no URL"
    assert_equal [ 1, 2, 3 ], bc["itemListElement"].map { |i| i["position"] }
  end

  test "the breadcrumb's first two rungs are URLs that resolve" do
    # hreflang work in this repository has twice pointed at URLs that did not
    # exist. A breadcrumb that does the same describes a site that is not there.
    post = create_jp_post(ep: 83, slug: "jp-ep83-geo-rungs")
    get "/ja/blog/#{post.slug}"
    bc = ld_blocks(utf8_body).find { |b| b["@type"] == "BreadcrumbList" }

    bc["itemListElement"].filter_map { |i| i["item"] }.each do |url|
      get URI.parse(url).path
      assert_response :success, "breadcrumb rung #{url} does not resolve"
    end
  end

  test "the breadcrumb is rendered, not only declared" do
    # This repository's standing rule: structured data must not announce a
    # section the document does not contain (the FAQ block is absent for the
    # same reason when there is no FAQ).
    post = create_jp_post(ep: 84, slug: "jp-ep84-geo-visible")
    get "/ja/blog/#{post.slug}"
    assert_select "nav.jp-breadcrumb" do
      assert_select "a[href='/ja']", text: "ホーム"
      assert_select "a[href='/ja/blog']", text: "ブログ"
      assert_select ".jp-breadcrumb-current", text: post.title(:ja)
    end
  end

  test "a Korean article gains NO logo and NO breadcrumb" do
    # The half that fails silently. E-1 captures canonical/robots/hreflang/
    # og:locale/html lang from the rendered HTML and cannot see JSON-LD, so
    # without this the Korean track's structured data could change and all 38
    # snapshot rows would still compare byte-identical.
    get "/blog/#{posts(:korean_only).slug}"
    assert_response :success
    blocks = ld_blocks(utf8_body)

    article = blocks.find { |b| b["@type"] == "Article" }
    assert article, "premise: the Korean article still has an Article block"
    # Unchanged by S11b: the rename is the JP branch only, and the 42 live
    # Korean posts' markup does not move. This is the assertion that makes the
    # ternary in show.html.erb a change to the SOURCE and not to the OUTPUT.
    assert_equal({ "@type" => "Organization", "name" => "SlimFile", "url" => "https://slimfile.net" },
                 article["publisher"],
                 "the Korean track's publisher block moved")
    assert_nil blocks.find { |b| b["@type"] == "BreadcrumbList" },
               "the Korean track gained a BreadcrumbList"
    refute_includes utf8_body, "jp-breadcrumb"
  end

  test "an English-URL Japanese article keeps its breadcrumb on the /en prefix" do
    # A Japanese episode with a body_en is canonical at /en/blog/:slug. A trail
    # whose first two rungs said /ja while the page said /en would describe a
    # different document's position in the site.
    post = create_jp_post(ep: 85, slug: "jp-ep85-geo-en", body_en: "<p>English body.</p>",
                          title_en: "Breadcrumb on the English URL")
    get "/en/blog/#{post.slug}"
    assert_response :success

    bc = ld_blocks(utf8_body).find { |b| b["@type"] == "BreadcrumbList" }
    assert bc
    assert_equal [ "Home", "Blog", "Breadcrumb on the English URL" ],
                 bc["itemListElement"].map { |i| i["name"] }
    assert_equal [ "https://slimfile.net/en", "https://slimfile.net/en/blog", nil ],
                 bc["itemListElement"].map { |i| i["item"] }

    canonical = utf8_body[%r{<link[^>]+rel="canonical"[^>]+href="([^"]+)"}, 1]
    assert_equal "https://slimfile.net/en/blog/#{post.slug}", canonical,
                 "premise: this URL really is the canonical one for this post"
  end

  # ── 4. the landing pages are no longer orphans ────────────────────────────

  test "the tool page links to all three landing pages" do
    get "/safe/"
    assert_response :success
    html = utf8_body
    LANDING_PATHS.each do |path|
      assert_includes html, %(href="#{path}"),
                      "/safe/ — the one indexed page that can pass crawl budget on — does not link to #{path}"
    end
  end

  test "the shared footer links to all three landing pages on every Rails page" do
    # The reason this is the layout and not an article: the only Korean post
    # Google has indexed is /blog/resident-number-masking, whose body is owned
    # by blog:migrate_privacy and is not edited here.
    %w[/ /blog /faq /compress].each do |path|
      get path
      assert_response :success
      html = utf8_body
      assert_select "footer.global-footer", 1
      LANDING_PATHS.each do |lp|
        assert_includes html, %(href="#{lp}"), "#{path} does not link to #{lp}"
      end
    end
  end

  test "the footer lead-in is translated and the page names stay Japanese" do
    { "/" => :ko, "/en" => :en, "/ja" => :ja, "/es" => :es }.each do |path, loc|
      get path
      assert_response :success
      assert_select "footer.global-footer .global-footer-jp" do |els|
        assert_includes els.first.text, I18n.t("site_footer.jp_label", locale: loc),
                        "#{path}: footer lead-in is not in #{loc}"
        assert_includes els.first.text, "入札添付"
      end
    end
  end

  test "/ja/blog shows the three landing cards and /blog does not" do
    get "/ja/blog"
    assert_select "a.jp-landing-card", 3
    LANDING_PATHS.each { |lp| assert_select "a.jp-landing-card[href=?]", lp }

    get "/blog"
    assert_select "a.jp-landing-card", 0
  end

  test "every landing page links back to the Japanese blog listing" do
    LANDING_PATHS.each do |path|
      get path
      assert_response :success
      assert_includes utf8_body, %(href="/ja/blog"),
                      "#{path} does not link to /ja/blog — the link has to go both ways or " \
                      "the listing is the only page that knows these exist"
    end
  end

  test "the new internal links resolve without a redirect" do
    # A link that 301s is a link Google follows at half value, and this
    # repository has shipped exactly that twice (/blog/ → /blog,
    # /safe/jp/… without the trailing slash). Collected from the rendered
    # footer rather than from a list retyped here.
    get "/"
    hrefs = utf8_body.scan(%r{<footer class="global-footer".*?</footer>}m).join
                     .scan(/href="(\/[^"]*)"/).flatten.uniq
    assert_operator hrefs.length, :>=, 4, "premise: the footer has links to check"

    hrefs.each do |href|
      get href
      assert_response :success, "#{href} does not answer 200 (it answered #{response.status})"
    end
  end

  private

  def create_jp_post(ep:, slug:, **attrs)
    Post.create!({
      content_track: "jp", content_ep: ep, primary_locale: "ja",
      status: "published", published_at: 1.day.ago, category: "privacy",
      slug: slug, title_ja: "提出書類の黒塗り、#{ep}回目",
      body_ja: "<p>本文</p>\n<p>提出先の指示を必ず確認してください。</p>",
      package: { "landing_path" => "/safe/jp/nyusatsu/" }
    }.merge(attrs))
  end
end
