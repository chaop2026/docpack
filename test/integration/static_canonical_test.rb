# frozen_string_literal: true

require "test_helper"

# Regression guard for the 2026-09-17 Search Console finding on /safe/
# ("Duplicate page without user-selected canonical").
#
# The defect had two halves and both are covered here:
#   1. /safe, /safe/ and /safe/index.html each answered an identical 200,
#      because ActionDispatch::FileHandler resolves all three to
#      public/safe/index.html — and it runs BEFORE the router, so the
#      `get "/safe", to: redirect("/safe/")` route never fired.
#   2. public/safe/index.html carried no <link rel="canonical">, so Google had
#      no user-selected canonical to consolidate the duplicates onto.
class StaticCanonicalTest < ActionDispatch::IntegrationTest
  CANONICAL_SAFE = "https://slimfile.net/safe/"

  # ── 1. duplicate spellings collapse onto the trailing-slash URL ──────────

  test "/safe permanently redirects to /safe/" do
    get "/safe"
    assert_response :moved_permanently
    assert_equal "/safe/", response.headers["location"]
  end

  test "/safe/index.html permanently redirects to /safe/" do
    get "/safe/index.html"
    assert_response :moved_permanently
    assert_equal "/safe/", response.headers["location"]
  end

  test "the redirect preserves the query string" do
    # The home page links to /safe/?v=20260719 (cache-buster); a visitor who
    # lands on /safe?v=… must keep it rather than silently lose the param.
    get "/safe?v=20260719"
    assert_response :moved_permanently
    assert_equal "/safe/?v=20260719", response.headers["location"]
  end

  test "the redirect is not cached permanently by the browser" do
    # A pinned 301 is effectively irreversible client-side; this app has been
    # bitten by a pinned static cache before (lib/static_html_no_cache.rb).
    get "/safe"
    assert_equal "no-cache", response.headers["cache-control"]
  end

  test "/privacy and /privacy/index.html collapse the same way" do
    get "/privacy"
    assert_response :moved_permanently
    assert_equal "/privacy/", response.headers["location"]

    get "/privacy/index.html"
    assert_response :moved_permanently
    assert_equal "/privacy/", response.headers["location"]
  end

  test "an ordinary query string round-trips readably in the 301 body" do
    # Escaping of hostile input is covered at the middleware level in
    # test/lib/static_index_redirect_test.rb — this stack percent-encodes the
    # query before the middleware sees it, so raw bytes cannot be injected here.
    get "/safe", params: { v: "20260719" }
    assert_includes response.body, %(<a href="/safe/?v=20260719">/safe/?v=20260719</a>)
  end

  test "the canonical URL itself is served, not redirected" do
    get "/safe/"
    assert_response :success
    assert_includes response.body, "SafeFile"
  end

  test "assets under /safe/ are untouched by the redirect" do
    %w[/safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest].each do |path|
      get path
      assert_response :success, "#{path} must not be redirected"
    end
  end

  # ── 2. the page declares its own canonical ──────────────────────────────

  test "/safe/ declares a self-referencing canonical with a trailing slash" do
    get "/safe/"
    assert_includes response.body, %(<link rel="canonical" href="#{CANONICAL_SAFE}">)
  end

  test "/safe/ declares x-default hreflang and nothing else" do
    # One URL serves all four languages via client-side i18n, so there is no
    # per-language URL to cross-reference. x-default self-reference is the only
    # hreflang that is true for this shape — adding ko/en/ja/es alternates
    # pointing at the same URL would be a false signal.
    get "/safe/"
    hreflangs = response.body.scan(/<link rel="alternate" hreflang="([^"]+)"/).flatten
    assert_equal ["x-default"], hreflangs
    assert_includes response.body,
                    %(<link rel="alternate" hreflang="x-default" href="#{CANONICAL_SAFE}">)
  end

  test "og:url matches the canonical URL" do
    get "/safe/"
    assert_includes response.body, %(<meta property="og:url" content="#{CANONICAL_SAFE}">)
  end

  test "/privacy/ keeps its own self-referencing canonical" do
    get "/privacy/"
    assert_includes response.body,
                    %(<link rel="canonical" href="https://slimfile.net/privacy/">)
  end

  # ── 3. the sitemap only ever advertises the canonical spelling ──────────

  test "sitemap lists /safe/ with a trailing slash and no duplicate spellings" do
    get "/sitemap.xml"
    assert_response :success
    assert_includes response.body, "<loc>https://slimfile.net/safe/</loc>"
    assert_not_includes response.body, "<loc>https://slimfile.net/safe</loc>"
    assert_not_includes response.body, "/safe/index.html"
    assert_not_includes response.body, "/safe/?v="
  end
end
