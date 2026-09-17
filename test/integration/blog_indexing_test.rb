# frozen_string_literal: true

require "test_helper"

# Guards the indexing signals a blog post sends, after the 2026-09-17 audit of
# Search Console's "not indexed: 63" report.
#
# The audit's finding was not that the noindex gate is wrong — it is right, and
# the first group of tests pins that down. It was that three *other* signals
# disagreed with it: the page's hreflang advertised four locales for posts that
# exist in one, the sitemap advertised URLs that disown their own address, and
# a URL that used to be an indexed page had started answering 404.
class BlogIndexingTest < ActionDispatch::IntegrationTest
  BASE = "https://slimfile.net"

  # x-default is excluded: it is a fallback pointer, not a language claim, and
  # the layout emits it for every page regardless of the narrowed locale set.
  def hreflangs(body)
    body.scan(/<link rel="alternate" hreflang="([^"]+)" href="([^"]+)"/)
        .reject { |loc, _| loc == "x-default" }
  end

  def x_default(body)
    body[/<link rel="alternate" hreflang="x-default" href="([^"]*)"/, 1]
  end

  def robots(body)
    body[/<meta name="robots" content="([^"]*)"/, 1]
  end

  def canonical(body)
    body[/<link rel="canonical" href="([^"]*)"/, 1]
  end

  # ── the noindex gate itself (this behaviour is intended; keep it) ────────

  test "a Korean-only post is indexable at its Korean URL" do
    get "/blog/korean-only-post"
    assert_response :success
    assert_nil robots(response.body), "the Korean original must not be noindexed"
    assert_equal "#{BASE}/blog/korean-only-post", canonical(response.body)
  end

  test "a Korean-only post is noindexed at every untranslated locale URL" do
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/korean-only-post"
      assert_response :success
      assert_equal "noindex,follow", robots(response.body),
                   "/#{loc}/blog/… serves the Korean body under a #{loc} shell"
      assert_equal "#{BASE}/blog/korean-only-post", canonical(response.body),
                   "…and must point at the Korean original"
    end
  end

  test "a translated post is indexable at the locale it was translated into" do
    get "/en/blog/bilingual-post"
    assert_response :success
    assert_nil robots(response.body)
    assert_equal "#{BASE}/en/blog/bilingual-post", canonical(response.body)
  end

  test "a translated post is still noindexed at locales it has no body for" do
    %w[ja es].each do |loc|
      get "/#{loc}/blog/bilingual-post"
      assert_equal "noindex,follow", robots(response.body)
    end
  end

  # ── publication state gates indexing too ────────────────────────────────
  #
  #   status      robots           why
  #   ---------   --------------   -------------------------------------------
  #   published   (none)           live, body exists in this locale
  #   published   noindex,follow   body not translated into this locale
  #   scheduled   noindex,follow   not live yet, but served for preview
  #   draft       noindex,follow   served for preview, never indexable

  test "a draft is still served for preview" do
    get "/blog/draft-post"
    assert_response :success, "the preview link must keep working"
    assert_includes response.body, "초안"
  end

  test "a draft is never indexable, in any locale" do
    ["/blog/draft-post", "/en/blog/draft-post", "/ja/blog/draft-post"].each do |path|
      get path
      assert_equal "noindex,follow", robots(response.body), "#{path} is an unpublished draft"
    end
  end

  test "a scheduled post is served for preview but never indexable" do
    get "/blog/scheduled-post"
    assert_response :success
    assert_equal "noindex,follow", robots(response.body)
  end

  test "an unpublished post advertises no alternates at all" do
    # [] is a real answer, not "unspecified" — and x-default goes with it, since
    # a fallback pointer to a page nobody may index says nothing true.
    %w[/blog/draft-post /blog/scheduled-post].each do |path|
      get path
      assert_empty hreflangs(response.body), "#{path} must advertise no locale"
      assert_nil x_default(response.body), "#{path} must not emit x-default either"
    end
  end

  test "publishing is what opens the gate" do
    # Same Korean body in both; only status differs.
    get "/blog/korean-only-post"
    assert_nil robots(response.body)
    get "/blog/draft-post"
    assert_equal "noindex,follow", robots(response.body)
  end

  test "an unpublished post never reaches the sitemap" do
    get "/sitemap.xml"
    %w[draft-post scheduled-post].each do |slug|
      assert_not_includes response.body, "/blog/#{slug}"
    end
  end

  # ── content follows the URL, not the reader's browser ────────────────────
  #
  # The half-fix this closes: canonical/robots moved onto the URL while
  # title/description/body kept reading I18n.locale, so an unprefixed URL served
  # English to an `Accept-Language: en` request — the same content as the /en URL
  # at a second address, under a Korean canonical.

  test "an unprefixed URL serves Korean whatever the browser asks for" do
    NEGOTIATION_HEADERS.each do |headers|
      get "/blog/bilingual-published-post", headers: headers
      lang = headers.values.first

      assert_includes response.body, "KOBODY", "body switched language for #{lang}"
      assert_not_includes response.body, "ENBODY", "English body leaked onto the Korean URL for #{lang}"
      assert_includes response.body, "이중언어 발행 글"
      assert_not_includes response.body, "Bilingual published post"
      assert_includes response.body, "KODESC"

      assert_equal "#{BASE}/blog/bilingual-published-post", canonical(response.body)
      assert_nil robots(response.body)
    end
  end

  test "the English URL serves English and canonicalises to itself" do
    get "/en/blog/bilingual-published-post"
    assert_includes response.body, "ENBODY"
    assert_not_includes response.body, "KOBODY"
    assert_includes response.body, "Bilingual published post"
    assert_includes response.body, "ENDESC"
    assert_equal "#{BASE}/en/blog/bilingual-published-post", canonical(response.body)
    assert_nil robots(response.body)
  end

  test "the English URL is unmoved by an opposing header" do
    get "/en/blog/bilingual-published-post",
        headers: { "HTTP_ACCEPT_LANGUAGE" => "ko-KR,ko;q=0.9" }
    assert_includes response.body, "ENBODY"
    assert_equal "#{BASE}/en/blog/bilingual-published-post", canonical(response.body)
  end

  test "a locale cookie does not move a post's content either" do
    get "/en/blog/bilingual-published-post"   # sets the locale cookie to en
    get "/blog/bilingual-published-post"
    assert_includes response.body, "KOBODY"
    assert_not_includes response.body, "ENBODY"
  end

  test "the listing follows the URL's locale too" do
    get "/blog", headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
    assert_includes response.body, "이중언어 발행 글"
    assert_not_includes response.body, "Bilingual published post"

    get "/en/blog"
    assert_includes response.body, "Bilingual published post"
  end

  test "a translated post is advertised under both locales and each self-canonicalises" do
    get "/blog/bilingual-published-post"
    assert_equal [
      ["ko", "#{BASE}/blog/bilingual-published-post"],
      ["en", "#{BASE}/en/blog/bilingual-published-post"]
    ], hreflangs(response.body)

    hreflangs(response.body).each do |_loc, href|
      get href.sub(BASE, "")
      assert_equal href, canonical(response.body)
      assert_nil robots(response.body)
    end
  end

  # ── hreflang must agree with the noindex gate ───────────────────────────

  test "a Korean-only post advertises only the Korean alternate" do
    get "/blog/korean-only-post"
    assert_equal [["ko", "#{BASE}/blog/korean-only-post"]], hreflangs(response.body)
  end

  test "hreflang never points at a URL that is noindexed" do
    # This is the contradiction the audit found: /ja/blog/:slug was advertised
    # as the Japanese alternate while itself carrying noindex.
    get "/blog/korean-only-post"
    hreflangs(response.body).each do |_loc, href|
      get href.sub(BASE, "")
      assert_nil robots(response.body), "#{href} is advertised via hreflang but is noindexed"
    end
  end

  test "hreflang never points at a URL that canonicalises elsewhere" do
    get "/blog/korean-only-post"
    hreflangs(response.body).each do |_loc, href|
      get href.sub(BASE, "")
      assert_equal href, canonical(response.body),
                   "#{href} is advertised via hreflang but disowns its own address"
    end
  end

  test "a translated post advertises both of its locales" do
    get "/blog/bilingual-post"
    assert_equal [
      ["ko", "#{BASE}/blog/bilingual-post"],
      ["en", "#{BASE}/en/blog/bilingual-post"]
    ], hreflangs(response.body)
  end

  test "an untranslated locale URL still advertises the Korean original" do
    get "/ja/blog/korean-only-post"
    assert_equal [["ko", "#{BASE}/blog/korean-only-post"]], hreflangs(response.body)
  end

  test "pages that are genuinely translated keep all four alternates" do
    # The narrowing must be scoped to posts — the UI pages really do exist in
    # every locale, so nothing about them changes.
    get "/faq"
    assert_equal %w[ko en ja es], hreflangs(response.body).map(&:first)
  end

  # ── the sitemap must agree with the pages ───────────────────────────────

  test "the sitemap lists no URL that canonicalises elsewhere" do
    get "/sitemap.xml"
    assert_response :success
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten

    assert_not locs.any? { |u| u.include?("?category=") },
               "category URLs declare canonical=/blog, so listing them contradicts the page"

    locs.grep(%r{/blog/}).each do |u|
      get u.sub(BASE, "")
      assert_equal u, canonical(response.body), "#{u} is in the sitemap but disowns its own address"
      assert_nil robots(response.body), "#{u} is in the sitemap but is noindexed"
    end
  end

  test "the sitemap lists a post only under the locales it was translated into" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten

    assert_includes locs, "#{BASE}/blog/korean-only-post"
    %w[en ja es].each do |loc|
      assert_not_includes locs, "#{BASE}/#{loc}/blog/korean-only-post"
    end

    assert_includes locs, "#{BASE}/blog/bilingual-post"
    assert_includes locs, "#{BASE}/en/blog/bilingual-post"
    %w[ja es].each do |loc|
      assert_not_includes locs, "#{BASE}/#{loc}/blog/bilingual-post"
    end
  end

  # ── indexing signals must come from the URL, not from negotiation ───────
  #
  # set_locale resolves a bare path through the cookie and then Accept-Language.
  # Keying canonical/robots on the result made one URL answer different crawlers
  # differently: GET /faq with `Accept-Language: en` declared canonical /en/faq,
  # and the Korean canonical /blog/:slug came back noindex.

  NEGOTIATION_HEADERS = [
    { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" },
    { "HTTP_ACCEPT_LANGUAGE" => "ja-JP,ja;q=0.9" },
    { "HTTP_ACCEPT_LANGUAGE" => "es-ES,es;q=0.9" }
  ].freeze

  test "an unprefixed page keeps its own canonical whatever language is requested" do
    %w[/ /compress /pdf /social /faq /about /blog].each do |path|
      get path
      baseline = canonical(response.body)
      assert_equal "#{BASE}#{path == '/' ? '/' : path}", baseline

      NEGOTIATION_HEADERS.each do |headers|
        get path, headers: headers
        assert_equal baseline, canonical(response.body),
                     "#{path} changed its canonical for #{headers.values.first}"
      end
    end
  end

  test "the Korean canonical post URL is never noindexed by a request header" do
    NEGOTIATION_HEADERS.each do |headers|
      get "/blog/korean-only-post", headers: headers
      assert_nil robots(response.body),
                 "/blog/korean-only-post went noindex for #{headers.values.first}"
      assert_equal "#{BASE}/blog/korean-only-post", canonical(response.body)
    end
  end

  test "a locale-prefixed URL is unaffected by an opposing header" do
    get "/en/blog/bilingual-post", headers: { "HTTP_ACCEPT_LANGUAGE" => "ko-KR,ko;q=0.9" }
    assert_nil robots(response.body)
    assert_equal "#{BASE}/en/blog/bilingual-post", canonical(response.body)
  end

  test "a locale cookie does not move a page's canonical either" do
    get "/en/faq"              # sets the locale cookie to en
    get "/faq"
    assert_equal "#{BASE}/faq", canonical(response.body)
  end

  # ── the blog listing's own meta ──────────────────────────────────────────

  test "the blog listing has its own title and description" do
    get "/blog"
    assert_not_equal "SlimFile", response.body[%r{<title>(.*?)</title>}m, 1].to_s.strip,
                     "page_meta must run from the view or the layout falls back to the default"
    assert_includes response.body, %(<meta property="og:url" content="#{BASE}/blog">)
  end

  test "each locale's blog listing self-canonicalises" do
    %w[en ja es].each do |loc|
      get "/#{loc}/blog"
      assert_equal "#{BASE}/#{loc}/blog", canonical(response.body)
    end
  end

  # ── structured data must name the same document as the canonical ────────

  test "the Article JSON-LD url matches the canonical, in every locale" do
    # These two fields were hardcoded to /blog/:slug with no locale prefix, so
    # an English post declared canonical /en/blog/… while its structured data
    # said /blog/… — the page and its metadata naming two different documents.
    {
      "/blog/bilingual-published-post" => "#{BASE}/blog/bilingual-published-post",
      "/en/blog/bilingual-published-post" => "#{BASE}/en/blog/bilingual-published-post",
      "/blog/korean-only-post" => "#{BASE}/blog/korean-only-post",
      # untranslated locales canonicalise home, and the JSON-LD must follow
      "/ja/blog/korean-only-post" => "#{BASE}/blog/korean-only-post"
    }.each do |path, expected|
      get path
      ld = JSON.parse(response.body[%r{<script type="application/ld\+json">(.*?)</script>}m, 1])
      assert_equal expected, canonical(response.body), path
      assert_equal expected, ld["url"], "#{path}: JSON-LD url"
      assert_equal expected, ld.dig("mainEntityOfPage", "@id"), "#{path}: JSON-LD @id"
    end
  end

  test "no JSON-LD field hardcodes an unprefixed post URL" do
    get "/en/blog/bilingual-published-post"
    ld = response.body[%r{<script type="application/ld\+json">(.*?)</script>}m, 1]
    assert_not_includes ld, "#{BASE}/blog/bilingual-published-post",
                        "a URL field still ignores the locale prefix"
  end

  # ── the stranded static URL ─────────────────────────────────────────────

  test "/blog/index.html redirects to the listing instead of 404ing" do
    # public/blog/index.html was a real indexed page until 9f8bfff deleted it;
    # afterwards it fell through to "/blog/:slug" as slug="index.html" → 404.
    get "/blog/index.html"
    assert_response :moved_permanently
    assert_redirected_to "/blog"
  end

  test "/blog/index.html keeps the reader's locale" do
    %w[en ja es].each do |loc|
      get "/#{loc}/blog/index.html"
      assert_response :moved_permanently
      assert_redirected_to "/#{loc}/blog"
    end
  end

  test "the index.html route does not shadow a real post" do
    get "/blog/korean-only-post"
    assert_response :success
  end
end
