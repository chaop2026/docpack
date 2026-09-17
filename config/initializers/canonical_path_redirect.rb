# frozen_string_literal: true

# Insert CanonicalPathRedirect in front of the static file server so every page
# has one address: `/safe` and `/safe/index.html` collapse onto `/safe/`, and
# every routed page's trailing-slash twin collapses onto the bare path.
# See lib/canonical_path_redirect.rb for the full rationale.
#
# It must sit ahead of ActionDispatch::Static: the static handler answers
# `/safe` from public/safe/index.html before the router ever sees it, which is
# why the equivalent route in config/routes.rb was dead code.
#
# Order vs StaticHtmlNoCache: both insert before ActionDispatch::Static, and
# initializers load alphabetically (canonical_path_redirect → static_html_no_cache),
# so this one ends up the *outer* of the two. That is harmless either way: the
# rewriter only touches responses carrying `public, max-age=…`, and this 301
# sends `no-cache`.
#
# Guarded so it is a no-op when ActionDispatch::Static is not in the stack
# (i.e. when a front-end proxy serves public/ instead of this app).
require Rails.root.join("lib", "canonical_path_redirect").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, CanonicalPathRedirect
) if Rails.application.config.public_file_server.enabled
