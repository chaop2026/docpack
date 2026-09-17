# frozen_string_literal: true

# Insert CanonicalPathRedirect so every page has one address: `/safe` and
# `/safe/index.html` collapse onto `/safe/`, every routed page's trailing-slash
# twin collapses onto the bare path, and repeated slashes collapse anywhere they
# appear. See lib/canonical_path_redirect.rb for the full rationale.
#
# ── Why this is inserted unconditionally ────────────────────────────────────
#
# It used to be wrapped in `if config.public_file_server.enabled`, copied from
# the sibling initializer below. That was right when this middleware only fixed
# static directories: with no ActionDispatch::Static there was nothing to get in
# front of. It stopped being right on 2026-09-18, when the middleware took over
# trailing-slash normalisation for *routed* pages (`/about/`, `/blog/:slug/`,
# `/sitemap.xml/`) — those have nothing to do with static file serving.
#
# Measured, not assumed: with the guard in place and `public_file_server.enabled`
# false, `bin/rails middleware` listed CanonicalPathRedirect zero times. Moving
# public/ behind nginx would therefore have deleted canonical-URL normalisation
# for the whole site with no error and no log line — the exact silent-failure
# shape this repo keeps getting bitten by.
#
# So the middleware always goes in. Only its POSITION depends on Static:
#
#   * Static present  — insert directly in front of it. Required: the file
#     handler answers `/safe` from public/safe/index.html before the router ever
#     sees the request, which is why the equivalent route in config/routes.rb
#     was dead code for as long as it existed.
#   * Static absent   — unshift to the top of the stack. There is nothing to
#     insert before, and `insert_before` would raise at boot ("No such
#     middleware to insert before"), turning a deployment change into a crash.
#     This does put it ahead of ActionDispatch::SSL, so a plain-HTTP request
#     would be normalised before being upgraded rather than after. Same two
#     hops either way (scheme, then spelling, in the other order), and the
#     Location stays path-only, so SSL still gets its turn.
#
# Order vs StaticHtmlNoCache: both target the front of the stack, and
# initializers load alphabetically (canonical_path_redirect →
# static_html_no_cache), so this one ends up the *outer* of the two. Harmless
# either way: the rewriter only touches responses carrying `public, max-age=…`,
# and this 301 sends `no-cache`.
#
# The guard on static_html_no_cache.rb is NOT the same mistake and stays put —
# that middleware exists purely to rewrite the cache headers Static emits, so
# without Static it genuinely has no work to do.
require Rails.root.join("lib", "canonical_path_redirect").to_s

if Rails.application.config.public_file_server.enabled
  Rails.application.config.middleware.insert_before(
    ActionDispatch::Static, CanonicalPathRedirect
  )
else
  Rails.application.config.middleware.unshift(CanonicalPathRedirect)
end
