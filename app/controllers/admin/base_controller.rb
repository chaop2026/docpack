module Admin
  class BaseController < ApplicationController
    layout "admin"

    # An admin session is good for twelve hours from the moment it was minted,
    # not from the last request. A sliding window never expires for the one
    # person who keeps the tab open, which is the tab most likely to be left
    # open on an unattended laptop.
    SESSION_MAX_AGE = 12.hours

    before_action :require_admin

    private

    def require_admin
      return redirect_to(admin_login_path) unless admin_session_live?

      true
    end

    # The single rule for "is this request carrying a live admin session?".
    #
    # It is a method on the base class rather than an inline check because
    # Admin::JpPackagesController#preview answers 404 instead of redirecting
    # (it must not confirm that an episode exists), and that branch used to
    # read `session[:admin_authenticated]` directly. Two call sites meant two
    # rules: adding expiry to one of them would have left the preview reachable
    # with a twelve-hour-old session, and nothing about the response would have
    # said so.
    #
    # Expired sessions are cleared, not just rejected — reset_session rather
    # than deleting the one key, so there is nothing left to resume from.
    def admin_session_live?
      return false unless session[:admin_authenticated]

      if session_expired?
        reset_session
        return false
      end

      true
    end

    # A session with no timestamp is treated as expired, not as fresh. Sessions
    # minted before 2026-11-07 have no `admin_authenticated_at`, and the honest
    # reading of "I do not know when this was issued" is "I cannot say it is
    # still valid" — the cost is one re-login, once.
    def session_expired?
      issued_at = session[:admin_authenticated_at]
      return true if issued_at.blank?

      Time.current.to_i - issued_at.to_i > SESSION_MAX_AGE.to_i
    end
  end
end
