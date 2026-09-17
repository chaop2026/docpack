# frozen_string_literal: true

require "test_helper"

# Search Console named three URLs on 2026-09-18, and every earlier guess about
# which they would be had been wrong. These tests pin the measured causes.
#
#   https://slimfile.net/api/safe_scan            404, first seen 2026-09-05
#   https://slimfile.net/en/about                 duplicate, Google-chosen canonical
#   https://slimfile.net/blog/contract-checklist/ duplicate, Google-chosen canonical
class CanonicalUrlsTest < ActionDispatch::IntegrationTest
  BASE = "https://slimfile.net"

  def canonical(body) = body[/<link rel="canonical" href="([^"]*)"/, 1]
  def robots(body) = body[/<meta name="robots" content="([^"]*)"/, 1]
  def hreflangs(body) = body.scan(/<link rel="alternate" hreflang="([^"]+)"/).flatten

  # ── the middleware is actually installed ────────────────────────────────

  test "CanonicalPathRedirect is in the stack, ahead of the static file server" do
    # Every assertion in this file is worthless if the middleware silently
    # stops being inserted — which is exactly what its old
    # `if public_file_server.enabled` guard could have caused the day public/
    # moved behind a proxy (measured: the middleware appeared zero times).
    #
    # This covers the branch this environment boots with (Static present). The
    # other branch cannot be exercised in-process, since the stack is built
    # once at boot; it was verified by booting the production environment with
    # public_file_server.enabled forced false and reading `bin/rails middleware`
    # — recorded in CLAUDE.md.
    names = Rails.application.middleware.map { |m| m.name.to_s }

    assert_includes names, "CanonicalPathRedirect"
    assert_includes names, "ActionDispatch::Static",
      "this environment is expected to serve public/ itself"
    assert_operator names.index("CanonicalPathRedirect"), :<,
      names.index("ActionDispatch::Static"),
      "the static handler would answer /safe before the middleware could redirect it"
  end

  # ── /api/safe_scan ──────────────────────────────────────────────────────

  test "the API endpoint is blocked from crawling in robots.txt" do
    # Not X-Robots-Tag: a noindex header has to be fetched to be obeyed, which
    # is the crawl we are preventing, and GET returns 404 so there is no
    # response of ours to attach a header to.
    get "/robots.txt"
    assert_match %r{^Disallow: /api/$}, response.body
  end

  test "GET on the API endpoint is still a 404 and that is fine" do
    # It is POST-only by design; robots.txt is what keeps crawlers away.
    get "/api/safe_scan"
    assert_response :not_found
  end

  # ── trailing slashes ────────────────────────────────────────────────────

  test "every routed page redirects its trailing-slash twin to the bare path" do
    {
      "/about/" => "/about",
      "/faq/" => "/faq",
      "/compress/" => "/compress",
      "/pdf/" => "/pdf",
      "/social/" => "/social",
      "/blog/" => "/blog",
      "/en/" => "/en",
      "/en/faq/" => "/en/faq",
      "/ja/compress/" => "/ja/compress",
      "/es/blog/" => "/es/blog",
      "/blog/korean-only-post/" => "/blog/korean-only-post",
      "/en/blog/bilingual-post/" => "/en/blog/bilingual-post"
    }.each do |path, target|
      get path
      assert_response :moved_permanently, path
      assert_redirected_to target
    end
  end

  test "the static directories keep their trailing slash" do
    %w[/safe/ /privacy/].each do |path|
      get path
      assert_response :success, "#{path} is a real directory under public/"
    end
    get "/safe"
    assert_redirected_to "/safe/"
  end

  test "a renamed slug spelled with a trailing slash still lands on the new address" do
    # Two hops, by design and bounded: this middleware normalises *spelling* and
    # runs ahead of the router, which resolves the *move*. So
    # /blog/contract-checklist/ → /blog/contract-checklist → the new slug.
    # Pulling the slug table into the middleware would collapse it to one hop
    # and make the route in config/routes.rb dead code — the exact trap /safe
    # fell into. Two 301s is the cheaper price.
    #
    # The targets no longer carry a trailing slash of their own, which would
    # have added a third hop.
    get "/blog/contract-checklist/"
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-checklist"

    follow_redirect!
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-sharing-checklist"

    follow_redirect!
    assert_response :not_found, "the fixture set has no such post, but the chain terminates"
  end

  test "the bare spelling of a renamed slug is still one hop" do
    get "/blog/contract-checklist"
    assert_response :moved_permanently
    assert_redirected_to "/blog/contract-sharing-checklist"

    get "/en/blog/rrn-masking"
    assert_response :moved_permanently
    assert_redirected_to "/en/blog/resident-number-masking"
  end

  # ── repeated slashes ────────────────────────────────────────────────────
  #
  # Both layers behind the middleware are blind to a repeated slash:
  # FileHandler resolves /safe//index.html to the same file as
  # /safe/index.html, and the router matches /en//about as /en/about. Measured
  # locally 2026-09-18 before the fix: every path below answered a 200 whose
  # body was byte-identical to its canonical twin, and /safe//index.html walked
  # past the /safe/index.html rule entirely.
  #
  # These go through the full stack, so they prove the *app* has one address per
  # page. The middleware's own rules are pinned at the Rack level in
  # test/lib/canonical_path_redirect_test.rb, where the path can be handed over
  # verbatim.

  test "repeated slashes collapse onto the canonical address" do
    {
      "/safe//" => "/safe/",
      "/safe///" => "/safe/",
      "/safe//index.html" => "/safe/",
      "/safe/index.html/" => "/safe/",
      "/privacy//" => "/privacy/",
      "/privacy//index.html" => "/privacy/",
      "/safe//sw.js" => "/safe/sw.js",
      "/safe/sw.js/" => "/safe/sw.js",
      "//about" => "/about",
      "/en//about" => "/en/about",
      "//faq" => "/faq",
      "//blog" => "/blog",
      "/blog//contract-sharing-checklist" => "/blog/contract-sharing-checklist",
      "//sitemap.xml" => "/sitemap.xml"
    }.each do |path, target|
      get path
      assert_response :moved_permanently, "#{path} should not answer directly"
      assert_equal target, response.headers["location"], path
    end
  end

  test "no redirect chain loops or exceeds two hops" do
    %w[/about/ /blog/ /en/faq/ /blog/contract-checklist/ /safe /safe/index.html
       /blog/index.html /blog/rrn-masking/
       /safe// /safe/// /safe//index.html /safe/index.html/ /safe//sw.js
       /safe/sw.js/ /privacy// //about /en//about /en///about //faq
       /blog//contract-checklist /blog//contract-checklist/ //sitemap.xml
       // ///].each do |path|
      get path
      seen = [path]
      hops = 0
      while response.redirect? && hops < 5
        loc = response.headers["location"].sub("http://www.example.com", "")
        assert_not_includes seen, loc, "#{path} loops at #{loc}"
        seen << loc
        follow_redirect!
        hops += 1
      end
      assert_operator hops, :<=, 2, "#{path} took #{hops} hops: #{seen.inspect}"
    end
  end

  test "no sitemap URL is itself a redirect" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    locs.each do |u|
      get u.sub(BASE, "")
      assert_response :success, "#{u} is advertised in the sitemap but redirects"
    end
  end

  # ── /about is one document, not four ────────────────────────────────────

  test "the about page canonicalises every locale onto /about" do
    %w[/about /en/about /ja/about /es/about].each do |path|
      get path
      assert_response :success, path
      assert_equal "#{BASE}/about", canonical(response.body), path
    end
  end

  test "only the unprefixed about page is indexable" do
    get "/about"
    assert_nil robots(response.body)

    %w[/en/about /ja/about /es/about].each do |path|
      get path
      assert_equal "noindex,follow", robots(response.body),
                   "#{path} serves the same English document as /about"
    end
  end

  test "the about page claims no language at all" do
    # Hardcoded English with no t() calls: declaring itself the Korean or
    # Japanese alternate would be a false claim, and x-default would be too.
    %w[/about /en/about].each do |path|
      get path
      assert_empty hreflangs(response.body), path
    end
  end

  test "the sitemap lists about once, unprefixed" do
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    assert_includes locs, "#{BASE}/about"
    %w[en ja es].each { |loc| assert_not_includes locs, "#{BASE}/#{loc}/about" }
  end

  test "genuinely translated pages keep all four locale URLs" do
    # The narrowing must not leak onto /faq, /compress or / — those really are
    # translated (28-38% similar to Korean, measured, vs 92-94% for about).
    get "/sitemap.xml"
    locs = response.body.scan(%r{<loc>([^<]+)</loc>}).flatten
    %w[/faq /compress /pdf /social].each do |path|
      %w[en ja es].each do |loc|
        assert_includes locs, "#{BASE}/#{loc}#{path}"
      end
    end
    get "/en/faq"
    assert_nil robots(response.body)
    assert_equal %w[ko en ja es x-default], hreflangs(response.body)
  end
end
