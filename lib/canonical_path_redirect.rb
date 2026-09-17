# frozen_string_literal: true

require "cgi/escape"

# Rack middleware that gives every page exactly one spelling of its address.
#
# Two different layers were handing out duplicates, in opposite directions:
#
#   1. ActionDispatch::FileHandler resolves a request for `/safe` by probing
#      `public/safe`, `public/safe.html` and finally `public/safe/index.html`,
#      so `/safe`, `/safe/` and `/safe/index.html` all returned an identical
#      200. And because ActionDispatch::Static sits *in front of* the router,
#      `get "/safe", to: redirect("/safe/")` never ran — the static handler
#      answered first and the route was dead code.
#
#   2. The Rails router matches a trailing slash as if it were not there, so
#      every routed page answered twice as well: `/about` and `/about/`,
#      `/blog/:slug` and `/blog/:slug/`, down to `/sitemap.xml/`. Measured live
#      2026-09-17: 168 of 168 post URLs and 32 other paths, all real 200s, no
#      redirect involved. Search Console had already picked one of them up —
#      `/blog/contract-checklist/` was reported as a duplicate whose canonical
#      Google chose for itself.
#
# These need opposite fixes, which is why one middleware owns both: a static
# directory is canonical WITH the trailing slash (that is what `public/safe/`
# is), and a routed page is canonical WITHOUT it.
#
# It must be inserted BEFORE ActionDispatch::Static (see the initializer) or the
# static handler wins again for case 1.
class CanonicalPathRedirect
  # Directory-backed static HTML entrypoints, spelled without the trailing
  # slash. Each is served from `public/<dir>/index.html` and is canonical WITH
  # the slash. These are the only two directories under public/ (verified), and
  # both are declared that way in the sitemap.
  DIRS = %w[/safe /privacy].freeze

  # Only GET/HEAD are redirected. A POST must never be turned into a 301 — the
  # method and body would be silently dropped by the client.
  SAFE_METHODS = %w[GET HEAD].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    target = canonical_target(env)
    return @app.call(env) unless target

    location = redirect_location(env, target)

    [
      301,
      {
        "location" => location,
        "content-type" => "text/html; charset=utf-8",
        # A permanently-cached 301 is effectively irreversible in the browser.
        # This app has already been bitten once by a pinned static cache
        # (see lib/static_html_no_cache.rb), so the redirect always revalidates.
        "cache-control" => "no-cache"
      },
      [body_for(location)]
    ]
  end

  private

  # Returns the canonical spelling of this path, or nil when the request is
  # already canonical and should pass through untouched.
  def canonical_target(env)
    return nil unless SAFE_METHODS.include?(env["REQUEST_METHOD"])

    path = env["PATH_INFO"].to_s
    return nil if path.empty? || path == "/"

    # Static directories: canonical WITH the slash.
    DIRS.each do |dir|
      return "#{dir}/" if path == dir || path == "#{dir}/index.html"
      # Already canonical, or an asset underneath it — never touched. This also
      # keeps the trailing-slash rule below from stripping `/safe/` itself.
      return nil if path.start_with?("#{dir}/")
    end

    # Routed pages: canonical WITHOUT the slash. Strip every trailing slash so
    # `/about//` resolves in one hop rather than redirecting twice.
    stripped = path.sub(%r{/+\z}, "")
    return nil if stripped == path

    stripped.empty? ? "/" : stripped
  end

  # The Location the client is sent to. The query string is echoed back from the
  # request, so strip anything that could break out of the header. Puma already
  # rejects a request line containing CR or LF, but relying on that would make
  # this middleware's safety a property of the upstream parser rather than of
  # this code — swap the server or put a proxy in front and the guarantee is
  # gone. Strip them here so the invariant holds on its own.
  def redirect_location(env, target)
    # SCRIPT_NAME is "" for a root-mounted app (the case here), but including it
    # keeps the Location correct if this app is ever mounted under a sub-path.
    #
    # String#delete takes a character SET, not a substring — this removes every
    # CR and every LF, not just the "\r\n" pair.
    query = env["QUERY_STRING"].to_s.delete("\r\n")
    location = "#{env["SCRIPT_NAME"]}#{target}"
    query.empty? ? location : "#{location}?#{query}"
  end

  # The 301 body is a courtesy for clients that do not follow Location (browsers
  # never render it). It still echoes request-controlled input, so escape it:
  # the same reasoning as above — the raw `<`, `>` and `"` that would make this
  # an injection are currently stopped by Puma's request-line parser, and that
  # is not a guarantee this file should depend on.
  def body_for(location)
    escaped = CGI.escapeHTML(location)
    "<html><body>Moved Permanently: <a href=\"#{escaped}\">#{escaped}</a></body></html>"
  end
end
