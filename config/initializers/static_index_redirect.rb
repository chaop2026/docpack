# frozen_string_literal: true

# Insert StaticIndexRedirect in front of the static file server so `/safe`,
# `/safe/index.html` (and the same pair for /privacy) 301 to the single
# canonical `/safe/` instead of each answering an identical 200.
# See lib/static_index_redirect.rb for the full rationale.
#
# Order vs StaticHtmlNoCache: both insert before ActionDispatch::Static, and
# initializers load alphabetically (static_html_no_cache → static_index_redirect),
# so this one ends up the *inner* of the two — the 301 travels back out through
# StaticHtmlNoCache. That is harmless: the rewriter only touches responses
# carrying `public, max-age=…`, and this 301 sends `no-cache`.
#
# Guarded so it is a no-op when ActionDispatch::Static is not in the stack
# (i.e. when a front-end proxy serves public/ instead of this app).
require Rails.root.join("lib", "static_index_redirect").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, StaticIndexRedirect
) if Rails.application.config.public_file_server.enabled
