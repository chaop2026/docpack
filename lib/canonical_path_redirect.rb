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
    return nil if path.empty?

    canonical = canonical_spelling(path)
    canonical == path ? nil : canonical
  end

  # The single canonical address for a path, in two steps that must happen in
  # this order: reduce the path to its bare form, then map that form onto the
  # address it belongs to.
  #
  # Normalising FIRST is what makes this correct, and it is the fix for the
  # duplicate family the earlier version left open. Repeated slashes are
  # invisible to the layers behind this one — ActionDispatch::FileHandler
  # resolves `/safe//index.html` to the same file as `/safe/index.html`, and the
  # Rails router matches `/en//about` as `/en/about` — so every extra slash was
  # another address serving identical bytes, and `/safe//index.html` walked
  # straight past the `/safe/index.html` rule. Measured locally 2026-09-18,
  # before the fix, byte-identical 200s across the board:
  #
  #   /safe//  /safe///  /safe//index.html  /safe//sw.js  /safe/sw.js/
  #   /privacy//  /privacy//index.html
  #   //about  /en//about  /en///about  //faq  //blog  //sitemap.xml
  #   /blog//some-slug  /en//blog//some-slug
  #
  # The last two rows are mid-path, not trailing, and no amount of trailing-slash
  # stripping would have caught them.
  #
  # Doing it in this order also bounds the fix to ONE hop: `/safe//index.html/`
  # reaches `/safe/` directly instead of through two 301s. Every value this
  # method can return is a fixed point of it — `/safe/` reduces to `/safe` which
  # maps back to `/safe/`, and a bare routed path maps to itself — so a redirect
  # can never chain or loop. That is asserted in the tests.
  def canonical_spelling(path)
    bare = path.squeeze("/").sub(%r{/+\z}, "")
    return "/" if bare.empty?

    # Static directories are canonical WITH the trailing slash (that is what
    # `public/safe/` actually is); routed pages are canonical without it, which
    # is what `bare` already holds.
    DIRS.each do |dir|
      return "#{dir}/" if bare == dir || bare == "#{dir}/index.html"
    end

    bare
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
