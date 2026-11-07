module Admin
  class SessionsController < ApplicationController
    layout "admin"

    # ── Why the rate limiter is handed an explicit store ───────────────────────
    #
    # `rate_limit` defaults to `store: cache_store`, and that default is
    # evaluated ONCE, when this class is loaded — the before_action closure then
    # holds that object for the life of the process. Measured in this app:
    #
    #     ActionController::Base.cache_store.equal?(Rails.cache)  # => true
    #
    # They are the same object, which is exactly why capturing it is a hazard
    # rather than a detail: anything that later replaces `Rails.cache` (the test
    # suite's CacheStoreHelper does precisely that, and config/environments/
    # test.rb starts on :null_store) leaves the limiter still counting into the
    # store it captured at boot. The limiter would then be a silent no-op — it
    # answers "not over the limit" forever and nothing in the response
    # distinguishes that from "under the limit". A brute-force guard that can
    # stop guarding without saying so is the failure mode this whole unit is
    # about.
    #
    # So the store is a thin proxy that resolves `Rails.cache` at call time. In
    # production this is the same :solid_cache_store the default would have
    # captured (atomic `increment` via SELECT … FOR UPDATE), so behaviour is
    # unchanged; under test it follows the store the test installed, which is
    # what makes "the 6th attempt is refused" assertable at all.
    # `**options` rather than a positional hash: ActionController::RateLimiting
    # calls `store.increment(key, 1, expires_in: within)`, and under Ruby 3
    # those keywords are not collected into a trailing positional parameter —
    # a `options = nil` signature raises ArgumentError on the first request.
    LIVE_CACHE = Module.new do
      def self.increment(name, amount = 1, **options)
        Rails.cache.increment(name, amount, **options)
      end
    end

    # Five attempts per minute per IP. Registered first so it runs before the
    # password is read: a guess that is refused for being the sixth must not
    # also get a comparison against the real secret.
    rate_limit to: 5, within: 1.minute,
               store: LIVE_CACHE,
               with: -> { refuse(:too_many_attempts, :too_many_requests) },
               only: :create

    def new
    end

    def create
      secret = admin_password

      # Fail closed. Until 2026-11-07 this read
      # `ENV.fetch("ADMIN_PASSWORD", "docpack2025")`, so a deployment that
      # forgot the variable did not fail — it quietly accepted a password
      # published in a PUBLIC repository's history. The fallback is gone, and a
      # missing secret now refuses every login instead of accepting one.
      if secret.blank?
        Rails.logger.warn("[admin] login refused: ADMIN_PASSWORD is not set")
        return refuse(:not_configured)
      end

      unless ActiveSupport::SecurityUtils.secure_compare(submitted_password, secret)
        return refuse(:invalid)
      end

      # Session fixation: a visitor who arrives with an attacker-supplied
      # session id must not have that id promoted to an authenticated one.
      # reset_session discards the whole session (flash included), so the
      # notice below is written into the NEW session — the redirect and the
      # message a human sees are unchanged.
      reset_session
      session[:admin_authenticated] = true
      session[:admin_authenticated_at] = Time.current.to_i

      redirect_to admin_banners_path, notice: "Logged in."
    end

    def destroy
      reset_session
      redirect_to admin_login_path, notice: "Logged out."
    end

    private

    # Three refusal wordings, all generic about the SECRET and specific about
    # the SITUATION. None of them reveals anything about the stored password —
    # not its length, not whether the submitted one was close, not whether a
    # given username exists (there is no username). What they do distinguish is
    # the three states an operator has to tell apart to fix anything:
    #
    #   not_configured    the server has no secret, so nothing can log in
    #   invalid           the secret exists and this was not it
    #   too_many_attempts the guard stopped reading passwords for a minute
    #
    # Hiding "not configured" behind "invalid" would buy nothing — a server with
    # no secret accepts no password, so there is no brute force to slow down —
    # and would cost the operator the one message that explains the outage.
    # Korean, by way of config.i18n.fallbacks = [:ko]: an admin arriving with a
    # ja/es locale cookie still gets a sentence rather than a missing-key trace.
    def refuse(reason, status = :unprocessable_entity)
      Rails.logger.info("[admin] login refused (#{reason})")
      flash.now[:alert] = t("admin_auth.#{reason}")
      render :new, status: status
    end

    # Coerced to a String: `password[]=a` or `password[k]=v` makes params[:password]
    # an Array / Parameters, and secure_compare raises on a non-String.
    def submitted_password
      params[:password].to_s
    end

    def admin_password
      ENV["ADMIN_PASSWORD"].to_s
    end
  end
end
