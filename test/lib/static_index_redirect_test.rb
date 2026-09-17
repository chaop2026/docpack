# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib", "static_index_redirect").to_s

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
class StaticIndexRedirectTest < ActiveSupport::TestCase
  # Inner app stands in for ActionDispatch::Static; a 200 means "passed through".
  PASSTHROUGH = ->(env) { [200, { "content-type" => "text/html" }, ["STATIC:#{env["PATH_INFO"]}"]] }

  def call(path, method: "GET", query: "", script_name: "")
    StaticIndexRedirect.new(PASSTHROUGH).call(
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
    %w[/safe/ /privacy/ /safe/sw.js /safe/icon.svg /safe/manifest.ko.webmanifest
       /api/safe_scan /safety /blog/safe].each do |path|
      status, = call(path)
      assert_equal 200, status, path
    end
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

  test "the redirect is not cached permanently by the browser" do
    _, headers, = call("/safe")
    assert_equal "no-cache", headers["cache-control"]
    assert_equal "text/html; charset=utf-8", headers["content-type"]
  end
end
