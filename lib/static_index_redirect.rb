# frozen_string_literal: true

# Rack middleware that collapses the duplicate URLs a static-directory page
# otherwise answers on, into one canonical trailing-slash URL.
#
# Why this exists (2026-09-17, GSC "Duplicate without user-selected canonical"):
# `ActionDispatch::FileHandler` resolves a request for `/safe` by probing
# `public/safe`, `public/safe.html` and finally `public/safe/index.html` — so
# `/safe`, `/safe/` and `/safe/index.html` all returned an identical 200. And
# because ActionDispatch::Static sits *in front of* the router, the
# `get "/safe", to: redirect("/safe/")` route in config/routes.rb never ran:
# the static handler answered first and the redirect was dead code.
#
# Three URLs × identical bytes × no `<link rel=canonical>` is the textbook input
# for Google's "Duplicate without user-selected canonical". The canonical tag on
# the page is the primary fix; this middleware removes the duplicates at the
# source so Google never has to consolidate them in the first place.
#
# Must be inserted BEFORE ActionDispatch::Static (see the initializer) or the
# static handler wins again.
class StaticIndexRedirect
  # Directory-backed static HTML entrypoints, without the trailing slash.
  # Each one is served from `public/<dir>/index.html`.
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

    # SCRIPT_NAME is "" for a root-mounted app (the case here), but including it
    # keeps the Location correct if this app is ever mounted under a sub-path.
    query = env["QUERY_STRING"].to_s
    location = "#{env["SCRIPT_NAME"]}#{target}"
    location = "#{location}?#{query}" unless query.empty?

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
      ["<html><body>Moved Permanently: <a href=\"#{location}\">#{location}</a></body></html>"]
    ]
  end

  private

  # Returns the canonical "/dir/" path when this request is one of the duplicate
  # spellings, or nil when the request should pass through untouched.
  def canonical_target(env)
    return nil unless SAFE_METHODS.include?(env["REQUEST_METHOD"])

    path = env["PATH_INFO"].to_s
    DIRS.each do |dir|
      return "#{dir}/" if path == dir || path == "#{dir}/index.html"
    end
    nil
  end
end
