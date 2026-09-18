#!/usr/bin/env bash
# Prints the production middleware stack under three static-file-serving configs,
# to check that CanonicalPathRedirect is present AND in front of ActionDispatch::Static.
#
# Run inside the web container:
#   docker compose exec -T web bash script/middleware_probe.sh
#
# The third config (public_file_server.enabled = false) is produced by a
# temporary initializer named to sort BEFORE canonical_path_redirect.rb, because
# that initializer reads the flag at load time. The file is removed on exit.
set -u

BASE_ENV="RAILS_ENV=production SECRET_KEY_BASE=dummy DB_HOST=db DB_USERNAME=postgres DB_PASSWORD=postgres"
PROBE=config/initializers/aaa_static_probe.rb
cleanup() { rm -f "$PROBE"; }
trap cleanup EXIT

stack() {
  env $BASE_ENV ${2:-} bin/rails middleware 2>/dev/null \
    | grep -nE "CanonicalPathRedirect|ActionDispatch::Static|ActionDispatch::SSL|StaticHtmlNoCache|^run "
}

echo "=== 1. RAILS_SERVE_STATIC_FILES=true (real deploy shape) ==="
stack x RAILS_SERVE_STATIC_FILES=true
echo
echo "=== 2. unset (framework default) ==="
stack x ""
echo
echo "=== 3. public_file_server.enabled = false (public/ behind a proxy) ==="
printf 'Rails.application.config.public_file_server.enabled = false\n' > "$PROBE"
stack x ""
