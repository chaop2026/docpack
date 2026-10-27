require "test_helper"

# The posture that keeps X posting off until somebody decides otherwise.
#
# Two independent things have to be true, and before S9 only one of them was:
#
#   1. `XClient.dry_run?` must be true when X_API_DRY_RUN=1 EVEN IF all four
#      credentials are present. That was already the code's shape; what was
#      missing was a test, and the untested half is the half that matters —
#      the no-credentials case is the one that cannot post anyway.
#
#   2. The variable has to actually REACH the production container. It did not.
#      `config/deploy.yml` never mentioned it, so the only reason production
#      was in dry run was that the credentials were absent. Adding the four
#      credentials would have switched live posting on as a side effect of an
#      unrelated deploy, with nothing in any diff saying so.
class JpDryRunPostureTest < ActionDispatch::IntegrationTest
  CREDS = %w[X_API_KEY X_API_SECRET X_ACCESS_TOKEN X_ACCESS_SECRET].freeze

  # ENV is process-global and these tests write to it, so every one of them
  # restores exactly what it found — including keys that were absent, which
  # `ENV[k] = nil` deletes rather than setting to "".
  def with_env(pairs)
    before = pairs.keys.to_h { |k| [ k, ENV[k] ] }
    pairs.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    before.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  # ── 1. the flag wins over the credentials ───────────────────────────────────

  test "X_API_DRY_RUN=1 forces dry run even with all four credentials present" do
    with_env(CREDS.to_h { |k| [ k, "present-but-must-not-be-used" ] }.merge("X_API_DRY_RUN" => "1")) do
      assert XClient.credentials_present?,
             "the premise of this test is that the credentials ARE there"
      assert XClient.dry_run?,
             "the flag must beat the credentials — otherwise adding keys turns live posting on"
      assert XClient.new.dry_run?, "the instance method must agree with the class method"
    end
  end

  # The inverse, so the assertion above is not passing for the wrong reason: if
  # `dry_run?` were hardcoded true, both tests would be green and neither would
  # mean anything.
  test "with the flag off and all four credentials present, dry run is OFF" do
    with_env(CREDS.to_h { |k| [ k, "x" ] }.merge("X_API_DRY_RUN" => nil)) do
      refute XClient.dry_run?,
             "this is the live-posting configuration; if it cannot be reached, the test above is vacuous"
    end
  end

  test "a missing credential is enough on its own, whatever the flag says" do
    CREDS.each do |missing|
      present = (CREDS - [ missing ]).to_h { |k| [ k, "x" ] }
      with_env(present.merge(missing => nil, "X_API_DRY_RUN" => nil)) do
        refute XClient.credentials_present?
        assert XClient.dry_run?, "#{missing} absent must force dry run"
      end
    end
  end

  test "the flag is only honoured as the exact string 1" do
    # Named because it is a sharp edge rather than an accident: "true", "yes"
    # and "0" all leave posting LIVE when the credentials are there. The
    # deploy.yml value is quoted "1" for this reason — YAML would otherwise
    # hand Kamal a boolean and the container would see "true".
    with_env(CREDS.to_h { |k| [ k, "x" ] }.merge("X_API_DRY_RUN" => "true")) do
      refute XClient.dry_run?, "only \"1\" counts — deploy.yml must not drift to true/yes"
    end
  end

  # ── 2. the flag reaches the container ───────────────────────────────────────

  test "deploy.yml declares X_API_DRY_RUN=1 as a clear (non-secret) env value" do
    # This test IS the safety mechanism, not a description of one. Deleting the
    # line from deploy.yml now fails the suite, so turning real posting on takes
    # a commit that touches this file too — which is exactly the deliberate,
    # reviewable act the posture asks for. A comment in a YAML file is not that.
    deploy = YAML.safe_load(Rails.root.join("config", "deploy.yml").read)
    clear = deploy.fetch("env").fetch("clear")

    assert_equal "1", clear["X_API_DRY_RUN"],
                 "config/deploy.yml env.clear must carry X_API_DRY_RUN: \"1\" — " \
                 "if you are intentionally enabling live X posting, delete this assertion in the same commit"
    assert_kind_of String, clear["X_API_DRY_RUN"],
                   "must be the quoted string \"1\"; unquoted YAML 1 is an Integer and ENV would see \"1\" " \
                   "only by luck of the serialiser"
    refute_includes Array(deploy.dig("env", "secret")), "X_API_DRY_RUN",
                    "not a secret — a secret is resolved from the host and leaves no trace in the diff, " \
                    "which is the property this line exists to avoid"
  end

  # ── /safefile → /safe/ ──────────────────────────────────────────────────────

  # The two layers spell Location differently and both are valid, so the
  # assertions compare the PATH rather than the whole header: the router's
  # `redirect()` emits an absolute URL (http://host/safe/) and
  # CanonicalPathRedirect emits a path-only one. Pinning the exact string would
  # make this test about which layer answered instead of about where the
  # reader lands.
  def redirect_path
    URI(response.headers["Location"]).path
  end

  test "/safefile 301s to /safe/ in one hop" do
    get "/safefile"
    assert_response :moved_permanently
    assert_equal "/safe/", redirect_path
  end

  test "/safefile/ reaches /safe/ too, and stops there" do
    # Two hops by design: CanonicalPathRedirect strips the trailing slash in
    # front of the router (hop 1) and the route above resolves the alias (hop
    # 2). Declaring `get "/safefile/"` would not shorten it — the router never
    # sees that spelling — it would only add a rule that cannot run.
    #
    # What matters is the DESTINATION and that the chain terminates, so both
    # are asserted rather than the hop count alone.
    get "/safefile/"
    assert_response :moved_permanently
    assert_equal "/safefile", redirect_path

    get redirect_path
    assert_response :moved_permanently
    assert_equal "/safe/", redirect_path
  end

  test "the alias does not swallow paths that merely start with safefile" do
    # `get "/safefile"` must not behave like a prefix match. If it did, a future
    # public/safefile-guide/ page would be unreachable and the 301 would be the
    # only thing anyone saw.
    get "/safefile-guide"
    assert_response :not_found
  end
end
