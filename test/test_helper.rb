ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# ── Admin password under test (S15 · 2026-11-07) ──────────────────────────────
#
# Admin::SessionsController used to read ENV.fetch("ADMIN_PASSWORD", "docpack2025"),
# and nothing in development or test ever set the variable — so every admin
# login in this suite was authenticating against that hardcoded fallback, which
# is published in this PUBLIC repository's history. The fallback is gone, so the
# suite has to supply its own value.
#
# Assigned (not `||=`) and assigned AFTER config/environment so it wins over
# dotenv-rails: a test that logs in must not depend on what the machine running
# it happens to export. This is a test fixture, not a secret.
ENV["ADMIN_PASSWORD"] = "s15-test-admin-password"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
