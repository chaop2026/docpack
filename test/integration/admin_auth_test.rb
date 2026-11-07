require "test_helper"
require "support/cache_store_helper"

# Admin login hardening — S15, 2026-11-07.
#
# What changed, and what each group of tests is here to hold:
#
#   1. fail closed      ENV.fetch("ADMIN_PASSWORD", "docpack2025") is gone. A
#                       server with no secret accepts nothing, including an
#                       empty submission (secure_compare("", "") is true, so
#                       the blank check has to come first — that is the trap).
#   2. secure_compare   constant-time, length-safe.
#   3. rate limit       five per minute per IP, then 429, checked BEFORE the
#                       password is read.
#   4. session lifetime twelve hours from issue; login re-mints the session id.
#
# The rate-limit tests need CacheStoreHelper: config/environments/test.rb uses
# :null_store, whose `increment` returns nil, so every counter in this app is a
# no-op under test. A "the cap works" assertion against the null store passes no
# matter what the cap does. Both directions are asserted here — with a store
# that remembers the sixth attempt is refused, and without one it is not —
# because the second half is what tells you the first half was measuring the cap
# rather than something else.
class AdminAuthTest < ActionDispatch::IntegrationTest
  include CacheStoreHelper

  PASSWORD = ENV.fetch("ADMIN_PASSWORD")

  # ── 1. fail closed ──────────────────────────────────────────────────────────

  test "login is refused when ADMIN_PASSWORD is unset" do
    without_admin_password do
      post admin_login_path, params: { password: "anything" }

      assert_response :unprocessable_entity
      assert_nil session[:admin_authenticated]
      assert_includes @response.body, I18n.t("admin_auth.not_configured", locale: :ko)
    end
  end

  # The one that matters: secure_compare("", "") is TRUE. Without the blank
  # check ahead of it, a server that forgot ADMIN_PASSWORD would hand the admin
  # area to anyone who submitted an empty form.
  test "an empty submission does not match an unset ADMIN_PASSWORD" do
    without_admin_password do
      post admin_login_path, params: { password: "" }
      assert_response :unprocessable_entity
      assert_nil session[:admin_authenticated]

      post admin_login_path
      assert_response :unprocessable_entity
      assert_nil session[:admin_authenticated]
    end
  end

  test "a whitespace-only ADMIN_PASSWORD counts as unset" do
    without_admin_password("   ") do
      post admin_login_path, params: { password: "   " }
      assert_response :unprocessable_entity
      assert_nil session[:admin_authenticated]
    end
  end

  # The fallback is gone from the source, not merely overridden by the suite's
  # ENV. Asserted on the file so that reinstating it is a test failure rather
  # than a code review the next person has to remember to do.
  #
  # Comment lines are stripped first. The first version of this test did not
  # strip them and went red on the comment that explains the removal — correctly,
  # because a raw-bytes assertion cannot tell code from prose. Stripping makes
  # the claim the one actually intended ("no code path reads a default") instead
  # of the one that happened to be easy to write ("this string is absent").
  test "the hardcoded password fallback is absent from the controller" do
    raw = Rails.root.join("app/controllers/admin/sessions_controller.rb").read
    code = raw.lines.reject { |line| line.strip.start_with?("#") }.join

    assert_includes raw, "docpack2025",
                    "the comment explaining the removal should stay"
    assert_not_includes code, "docpack2025",
                        "no code line may contain the published default"
    assert_no_match(/ENV\.fetch\(\s*["']ADMIN_PASSWORD["']\s*,/, code,
                    "ADMIN_PASSWORD must not be read with a default value")
  end

  test "the published default no longer opens the admin area" do
    post admin_login_path, params: { password: "docpack2025" }

    assert_response :unprocessable_entity
    assert_nil session[:admin_authenticated]
  end

  # ── 2. wrong / right password ───────────────────────────────────────────────

  test "a wrong password is refused with a generic message" do
    post admin_login_path, params: { password: "#{PASSWORD}x" }

    assert_response :unprocessable_entity
    assert_nil session[:admin_authenticated]
    assert_includes @response.body, I18n.t("admin_auth.invalid", locale: :ko)
    # The refusal must not say which of the three situations it was.
    assert_not_includes @response.body, I18n.t("admin_auth.not_configured", locale: :ko)
  end

  test "a password that is a prefix of the real one is refused" do
    post admin_login_path, params: { password: PASSWORD[0..-2] }

    assert_response :unprocessable_entity
    assert_nil session[:admin_authenticated]
  end

  # Array / hash parameter pollution: secure_compare raises TypeError on a
  # non-String, which would be a 500 — a distinguishable response, i.e. an
  # oracle, and a crash report per attempt.
  test "a non-string password parameter is refused, not raised on" do
    post admin_login_path, params: { password: [ PASSWORD ] }
    assert_response :unprocessable_entity

    post admin_login_path, params: { password: { value: PASSWORD } }
    assert_response :unprocessable_entity

    assert_nil session[:admin_authenticated]
  end

  test "the correct password logs in and records when" do
    freeze_time do
      post admin_login_path, params: { password: PASSWORD }

      assert_redirected_to admin_banners_path
      assert_equal "Logged in.", flash[:notice]
      assert session[:admin_authenticated]
      assert_equal Time.current.to_i, session[:admin_authenticated_at]
    end
  end

  # ── 3. rate limit ───────────────────────────────────────────────────────────

  test "the sixth attempt in a minute is refused with 429" do
    with_memory_cache do
      5.times do |i|
        post admin_login_path, params: { password: "wrong-#{i}" }
        assert_response :unprocessable_entity, "attempt #{i + 1} should still be read"
      end

      post admin_login_path, params: { password: "wrong-6" }
      assert_response :too_many_requests
      assert_includes @response.body, I18n.t("admin_auth.too_many_attempts", locale: :ko)
    end
  end

  # The limiter runs before the password is compared. If it ran after, a
  # determined guesser would be told "that one was right" on the attempt that
  # was supposed to be refused.
  test "the correct password is also refused once over the limit" do
    with_memory_cache do
      5.times { post admin_login_path, params: { password: "wrong" } }

      post admin_login_path, params: { password: PASSWORD }

      assert_response :too_many_requests
      assert_nil session[:admin_authenticated]
    end
  end

  test "the limit lifts when the window passes" do
    with_memory_cache do
      6.times { post admin_login_path, params: { password: "wrong" } }
      assert_response :too_many_requests

      travel 61.seconds do
        post admin_login_path, params: { password: PASSWORD }
        assert_redirected_to admin_banners_path
      end
    end
  end

  # Reverse guard. Without a store that remembers, there is no cap — and that is
  # the suite's default, so every other test in this file is unaffected by the
  # limiter. If this one ever goes red it means the test default changed and the
  # five-attempt assertions above are measuring something different.
  test "no cap fires without a cache that remembers" do
    assert_instance_of ActiveSupport::Cache::NullStore, Rails.cache

    10.times do
      post admin_login_path, params: { password: "wrong" }
      assert_response :unprocessable_entity
    end
  end

  # The limiter's store must follow Rails.cache at call time. If it captured
  # ActionController::Base.cache_store when the class was loaded (the Rails
  # default), with_memory_cache above would be writing to a store nobody reads
  # and the 429 tests could not pass at all.
  test "the rate limit store resolves Rails.cache per call" do
    store = Admin::SessionsController::LIVE_CACHE

    assert_nil store.increment("s15-probe", 1, expires_in: 1.minute),
                "null store should answer nil"

    with_memory_cache do
      assert_equal 1, store.increment("s15-probe", 1, expires_in: 1.minute)
      assert_equal 2, store.increment("s15-probe", 1, expires_in: 1.minute)
    end
  end

  # ── 4. session lifetime and fixation ────────────────────────────────────────

  test "an admin session older than twelve hours is sent back to login" do
    post admin_login_path, params: { password: PASSWORD }
    assert_redirected_to admin_banners_path

    travel 11.hours + 59.minutes do
      get admin_banners_path
      assert_response :success, "still inside the twelve-hour window"
    end

    travel 12.hours + 1.minute do
      get admin_banners_path
      assert_redirected_to admin_login_path
      assert_nil session[:admin_authenticated], "the expired session should be cleared"
      assert_nil session[:admin_authenticated_at]
    end
  end

  # Admin::JpPackagesController#preview answers 404 rather than redirecting, so
  # it does not confirm that an episode exists. Before S15 it read
  # session[:admin_authenticated] directly, which would have made it the one
  # admin surface an expired session could still reach. Both directions are
  # asserted — a live session renders it — otherwise "404" would pass for a
  # package that simply is not in the database.
  test "the jp preview 404 honours the same expiry" do
    make_jp_package
    post admin_login_path, params: { password: PASSWORD }

    get admin_jp_package_preview_path(JP_EP)
    assert_response :success, "a live session must be able to read the preview"

    travel 12.hours + 1.minute do
      get admin_jp_package_preview_path(JP_EP)
      assert_response :not_found
    end
  end

  test "logging in re-mints the session id" do
    post admin_login_path, params: { password: "wrong" }
    before = session.id.to_s
    assert_predicate before, :present?,
                     "a session has to exist before login for this to mean anything"

    post admin_login_path, params: { password: PASSWORD }
    after = session.id.to_s

    assert_predicate after, :present?
    assert_not_equal before, after,
                     "reset_session must discard the pre-login session id"
    assert session[:admin_authenticated]
  end

  test "logging out discards the session" do
    post admin_login_path, params: { password: PASSWORD }
    signed_in = session.id.to_s

    delete admin_logout_path

    assert_redirected_to admin_login_path
    assert_equal "Logged out.", flash[:notice]
    assert_nil session[:admin_authenticated]
    assert_nil session[:admin_authenticated_at]
    assert_not_equal signed_in, session.id.to_s

    get admin_banners_path
    assert_redirected_to admin_login_path
  end

  private

  JP_EP = 915

  def make_jp_package
    Post.create!(
      content_track: "jp", content_ep: JP_EP, primary_locale: "ja",
      status: "draft", category: "privacy", slug: "jp-ep#{JP_EP}-s15",
      title_ja: "セッション期限テスト", body_ja: "<p>本文</p>",
      published_at: 3.days.from_now,
      package: { "ep" => JP_EP, "track" => "jp", "guard" => { "violations" => [] } }
    )
  end

  def without_admin_password(value = nil)
    previous = ENV["ADMIN_PASSWORD"]
    if value.nil?
      ENV.delete("ADMIN_PASSWORD")
    else
      ENV["ADMIN_PASSWORD"] = value
    end
    yield
  ensure
    ENV["ADMIN_PASSWORD"] = previous
  end
end

# The "no issue time" case needs a session built by hand, which an integration
# test cannot do — it only has the cookie. ActionController::TestCase can set
# session keys directly, which is exactly the shape a pre-S15 session arrives
# in: `admin_authenticated` present, `admin_authenticated_at` absent.
class AdminStaleSessionTest < ActionController::TestCase
  tests Admin::BannersController

  test "a session with no issue time is treated as expired" do
    session[:admin_authenticated] = true

    get :index

    assert_redirected_to admin_login_path
    assert_nil session[:admin_authenticated], "the unknown-age session should be cleared"
  end

  test "a session issued just now is accepted" do
    session[:admin_authenticated] = true
    session[:admin_authenticated_at] = Time.current.to_i

    get :index

    assert_response :success
  end

  test "a session issued thirteen hours ago is refused" do
    session[:admin_authenticated] = true
    session[:admin_authenticated_at] = 13.hours.ago.to_i

    get :index

    assert_redirected_to admin_login_path
    assert_nil session[:admin_authenticated]
  end

  # The boundary is the constant, not a number copied into the test: a change to
  # SESSION_MAX_AGE should move both sides of this assertion together.
  test "the boundary is Admin::BaseController::SESSION_MAX_AGE" do
    max = Admin::BaseController::SESSION_MAX_AGE

    session[:admin_authenticated] = true
    session[:admin_authenticated_at] = max.ago.to_i
    get :index
    assert_response :success, "exactly at the limit is still live"

    session[:admin_authenticated] = true
    session[:admin_authenticated_at] = (max + 1.second).ago.to_i
    get :index
    assert_redirected_to admin_login_path
  end
end
