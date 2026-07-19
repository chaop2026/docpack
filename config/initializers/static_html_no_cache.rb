# frozen_string_literal: true

# Insert StaticHtmlNoCache in front of the static file server so static HTML
# entrypoints (/safe/, /privacy/, static blog posts) are served `no-cache`
# instead of inheriting the 1-year `public_file_server.headers` meant for
# digest-stamped assets. See lib/static_html_no_cache.rb for the full rationale.
#
# Only relevant when this app serves static files itself (RAILS_SERVE_STATIC_FILES
# in production; enabled by default in dev/test). Guarded so it is a no-op when
# ActionDispatch::Static is not in the stack.
require Rails.root.join("lib", "static_html_no_cache").to_s

Rails.application.config.middleware.insert_before(
  ActionDispatch::Static, StaticHtmlNoCache
) if Rails.application.config.public_file_server.enabled
