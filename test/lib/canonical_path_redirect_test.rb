# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib", "canonical_path_redirect").to_s

# Unit tests for the redirect middleware, driven with a hand-built Rack env.
#
# Why not drive these through ActionDispatch::IntegrationTest: that stack parses
# and percent-encodes the URI before the middleware runs, so `<`, `>`, `"` and
# CR/LF arrive already neutralised and the assertions would pass vacuously.
# Puma does the same in production — it answers 400 to a request line carrying
# those bytes. That is precisely the dependency these tests exist to remove: the
# escaping has to be a property of this file, not of whatever parser happens to
# sit in front of it. Handing the middleware a raw env is the only altitude at
# which that can actually be asserted.
class CanonicalPathRedirectTest < ActiveSupport::TestCase
  # Inner app stands in for ActionDispatch::Static; a 200 means "passed through".
  PASSTHROUGH = ->(env) { [200, { "content-type" => "text/html" }, ["STATIC:#{env["PATH_INFO"]}"]] }

  def call(path, method: "GET", query: "", script_name: "")
    CanonicalPathRedirect.new(PASSTHROUGH).call(
      "PATH_INFO" => path,
      "REQUEST_METHOD" => method,
      "QUERY_STRING" => query,
      "SCRIPT_NAME" => script_name
    )
  end

  # ── redirect targets ────────────────────────────────────────────────────

  test "duplicate spellings redirect to the trailing-slash URL" do
    {
      "/safe" => "/safe/",
      "/safe/index.html" => "/safe/",
      "/privacy" => "/privacy/",
      "/privacy/index.html" => "/privacy/"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "the canonical spelling and everything else passes through" do
    %w[/ /safe/ /privacy/ /safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest
       /api/safe_scan /safety /blog/safe /about /blog/some-slug].each do |path|
      status, = call(path)
      assert_equal 200, status, path
    end
  end

  # ── routed pages are canonical WITHOUT the trailing slash ───────────────
  #
  # The Rails router matches a trailing slash as if it were absent, so every
  # routed page answered twice. Measured live 2026-09-17: 168 of 168 post URLs
  # and 32 other paths returned a real 200 both ways, no redirect involved.

  test "a trailing slash on a routed page redirects to the bare path" do
    {
      "/about/" => "/about",
      "/faq/" => "/faq",
      "/blog/" => "/blog",
      "/blog/some-slug/" => "/blog/some-slug",
      "/en/" => "/en",
      "/en/about/" => "/en/about",
      "/ja/blog/some-slug/" => "/ja/blog/some-slug",
      "/sitemap.xml/" => "/sitemap.xml"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "the site root keeps its slash" do
    status, = call("/")
    assert_equal 200, status, "/ is already canonical and must not redirect"
  end

  test "repeated trailing slashes collapse in a single hop" do
    _, headers, = call("/about//")
    assert_equal "/about", headers["location"]
    _, headers, = call("/about///")
    assert_equal "/about", headers["location"]
  end

  # ── repeated slashes anywhere in the path ───────────────────────────────
  #
  # The layers behind this one cannot see a repeated slash: FileHandler resolves
  # `/safe//index.html` to the same file as `/safe/index.html`, and the Rails
  # router matches `/en//about` as `/en/about`. Every extra slash was therefore
  # another address serving identical bytes. Measured locally 2026-09-18 before
  # the fix — every path below answered 200 with a byte-identical body, and
  # `/safe//index.html` slipped past the `/safe/index.html` rule entirely.

  test "repeated slashes under a static directory collapse onto its canonical URL" do
    {
      "/safe//" => "/safe/",
      "/safe///" => "/safe/",
      "/safe//index.html" => "/safe/",
      "/safe///index.html" => "/safe/",
      "/safe/index.html/" => "/safe/",
      "/privacy//" => "/privacy/",
      "/privacy//index.html" => "/privacy/"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "repeated slashes in front of a static asset collapse onto the single asset URL" do
    {
      "/safe//sw.js" => "/safe/sw.js",
      "/safe///sw.js" => "/safe/sw.js",
      "/safe//manifest.ko.webmanifest" => "/safe/manifest.ko.webmanifest",
      # A trailing slash on an asset is a duplicate too: /safe/sw.js/ served the
      # same 8979 bytes as /safe/sw.js. The old code's "never touch anything
      # under a static dir" branch let this through.
      "/safe/sw.js/" => "/safe/sw.js",
      "/privacy//style.css" => "/privacy/style.css"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "repeated slashes mid-path on a routed page collapse in one hop" do
    # Not trailing — no amount of trailing-slash stripping would catch these.
    {
      "//about" => "/about",
      "/en//about" => "/en/about",
      "/en///about" => "/en/about",
      "//en/about" => "/en/about",
      "//faq" => "/faq",
      "//blog" => "/blog",
      "//sitemap.xml" => "/sitemap.xml",
      "/blog//some-slug" => "/blog/some-slug",
      "/en//blog//some-slug" => "/en/blog/some-slug",
      "//robots.txt" => "/robots.txt"
    }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  test "repeated slashes at the root collapse onto /" do
    { "//" => "/", "///" => "/", "////" => "/" }.each do |path, target|
      status, headers, = call(path)
      assert_equal 301, status, path
      assert_equal target, headers["location"], path
    end
  end

  # ── no chains, no loops ─────────────────────────────────────────────────
  #
  # Normalising the path before mapping it is what bounds this to a single hop.
  # Rather than trust that argument, follow the middleware's own output back
  # into itself: if any Location it emits would redirect again, the fix has
  # created a chain, and if one ever returns to its input it has created a loop.
  # (config/routes.rb may add a second hop for an old slug — that is the router,
  # deliberately accepted, and out of this middleware's reach. DECISIONS.md
  # 2026-09-18.)

  test "no Location this middleware emits redirects again" do
    paths = %w[
      / // /// //// /safe /safe/ /safe// /safe/// /safe/index.html /safe//index.html
      /safe/index.html/ /safe/sw.js /safe/sw.js/ /safe//sw.js /privacy /privacy/
      /privacy// /privacy//index.html /about /about/ /about// /about/// //about
      /en//about /en///about //en/about /faq/ //faq /blog/ //blog /blog//some-slug
      /en//blog//some-slug /sitemap.xml/ //sitemap.xml /robots.txt //robots.txt
      /api/safe_scan /blog/safe /safety /en /en/
    ]

    paths.each do |path|
      status, headers, = call(path)
      next if status == 200

      location = headers["location"]
      follow_status, follow_headers, = call(location)
      assert_equal 200, follow_status,
        "#{path} -> #{location} -> #{follow_headers["location"]} is a redirect chain"
      assert_not_equal path, location, "#{path} redirects to itself"
    end
  end

  test "every canonical spelling is a fixed point" do
    # The same invariant stated directly on the pure function, so a regression
    # is reported at the rule rather than at one of its symptoms.
    mw = CanonicalPathRedirect.new(PASSTHROUGH)
    %w[
      / // /safe /safe/ /safe// /safe/index.html /safe/sw.js/ /privacy//
      /about/ //about /en//about /blog//some-slug /sitemap.xml/ ////
    ].each do |path|
      once = mw.send(:canonical_spelling, path)
      twice = mw.send(:canonical_spelling, once)
      assert_equal once, twice, "canonical_spelling is not idempotent for #{path}"
    end
  end

  test "a static directory keeps its slash while routed paths lose theirs" do
    # The two rules point in opposite directions, which is why one middleware
    # owns both. /safe/ is a real directory under public/; /about/ is not.
    assert_equal 200, call("/safe/").first
    assert_equal 200, call("/privacy/").first
    assert_equal 301, call("/about/").first
  end

  test "assets underneath a static directory are never rewritten" do
    %w[/safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest /privacy/style.css].each do |path|
      assert_equal 200, call(path).first, path
    end
  end

  test "the trailing-slash redirect preserves the query string" do
    _, headers, = call("/blog/", query: "category=privacy")
    assert_equal "/blog?category=privacy", headers["location"]
  end

  test "only GET and HEAD lose the trailing slash" do
    assert_equal 301, call("/about/", method: "HEAD").first
    assert_equal 200, call("/about/", method: "POST").first
  end

  test "only GET and HEAD are redirected" do
    assert_equal 301, call("/safe", method: "HEAD").first
    # Turning a POST into a 301 would silently drop the method and body.
    assert_equal 200, call("/safe", method: "POST").first
    assert_equal 200, call("/privacy/index.html", method: "PUT").first
  end

  test "SCRIPT_NAME is preserved for a sub-path mount" do
    _, headers, = call("/safe", script_name: "/app")
    assert_equal "/app/safe/", headers["location"]
  end

  # ── query string handling ───────────────────────────────────────────────

  test "the query string is preserved" do
    _, headers, = call("/safe", query: "v=20260719")
    assert_equal "/safe/?v=20260719", headers["location"]
  end

  test "CR and LF are stripped from the Location header" do
    _, headers, = call("/safe", query: "a=1\r\nX-Injected: yes")
    assert_no_match(/[\r\n]/, headers["location"])
    assert_equal "/safe/?a=1X-Injected: yes", headers["location"]
  end

  # ── 301 body escaping ───────────────────────────────────────────────────

  test "HTML metacharacters from the query string are escaped in the body" do
    _, _, body = call("/safe", query: %(x="><script>alert(1)</script>))
    html = body.first

    assert_not_includes html, "<script>"
    assert_includes html, "&lt;script&gt;"
    assert_includes html, "&quot;"
    # The anchor the template itself writes is the only markup left standing.
    assert_equal 1, html.scan("<a href=").length
    assert_equal 1, html.scan("</a>").length
  end

  test "an attribute-breaking payload cannot escape the href" do
    _, _, body = call("/safe", query: %(x=a" onmouseover="alert(1)))
    html = body.first

    assert_not_includes html, "onmouseover=\"alert"
    assert_includes html, "&quot;"
    # exactly two quote characters remain: the ones delimiting href="…"
    assert_equal 2, html.count('"')
  end

  test "ampersands and single quotes are escaped" do
    _, _, body = call("/safe", query: "x=a&b='c'")
    html = body.first

    assert_includes html, "&amp;"
    assert_not_includes html, "'"
  end

  test "percent-encoded payloads stay inert and unmangled" do
    encoded = "x=%22%3E%3Cscript%3E"
    _, headers, body = call("/safe", query: encoded)

    assert_equal "/safe/?#{encoded}", headers["location"]
    assert_includes body.first, encoded
    assert_not_includes body.first, "<script>"
  end

  test "an ordinary query string stays readable in the body" do
    _, _, body = call("/safe", query: "v=20260719")
    assert_includes body.first, %(<a href="/safe/?v=20260719">/safe/?v=20260719</a>)
  end

  # ── response shape ──────────────────────────────────────────────────────

  test "the Location is always path-only and never echoes the Host" do
    # This is what makes the middleware safe to run at any depth in the stack.
    # When ActionDispatch::Static is absent the initializer unshifts it to the
    # very top — ahead of ActionDispatch::SSL — so a plain-HTTP request gets
    # normalised before being upgraded. That costs nothing only because the
    # Location carries no scheme and no host: SSL still gets its turn, and a
    # forged Host header has nothing to land in.
    %w[/safe /safe// /about/ //about /en//about /safe/sw.js/ //].each do |path|
      _, headers, = CanonicalPathRedirect.new(PASSTHROUGH).call(
        "PATH_INFO" => path,
        "REQUEST_METHOD" => "GET",
        "QUERY_STRING" => "",
        "SCRIPT_NAME" => "",
        "HTTP_HOST" => "evil.example.com",
        "HTTPS" => "off"
      )
      location = headers["location"]
      assert_match %r{\A/}, location, "#{path}: Location must be path-only, got #{location.inspect}"
      assert_not_includes location, "evil.example.com", path
      assert_not_includes location, "://", path
    end
  end

  test "the redirect is not cached permanently by the browser" do
    _, headers, = call("/safe")
    assert_equal "no-cache", headers["cache-control"]
    assert_equal "text/html; charset=utf-8", headers["content-type"]
  end
end
