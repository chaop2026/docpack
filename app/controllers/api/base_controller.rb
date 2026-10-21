module Api
  # Shared base for the three JSON endpoints under /api/.
  #
  # It exists for one reason: `ApplicationController#set_locale` writes a
  # one-year `locale` cookie whenever `params[:locale]` is present, and
  # `params` includes the query string. That is correct for a page — the visitor
  # clicked a language — but on an API route it means
  #
  #     POST /api/safe_events?locale=ja   →  204 + Set-Cookie: locale=ja
  #
  # which was measured, not theorised. An endpoint whose entire purpose is to
  # count things WITHOUT identifying anyone must not be able to plant a
  # persistent cookie, and the page that calls it promises exactly that.
  #
  # Nothing under /api/ renders a localized response: safe_scan's prompts are
  # hardcoded, jp_pilot answers with field NAMES so the page can supply its own
  # Japanese wording, and safe_events answers with no body at all. So the locale
  # filter has nothing to contribute here beyond the side effect.
  #
  # CSRF verification is skipped for the same set: these are JSON endpoints
  # called with fetch/sendBeacon from a static page that has no Rails-rendered
  # form and therefore no authenticity token to carry.
  #
  # ── Why skipping CSRF needs two guards of its own ───────────────────────────
  #
  # "None of them read the session, so there is no authority to borrow" is true
  # and was the whole justification until it was pointed out that it answers the
  # wrong question. A cross-site POST here does not need to borrow authority: a
  # plain HTML form on someone else's page posts form-urlencoded, Rails builds
  # the same `params` from it, and /api/jp_pilot writes a row and sends mail.
  # The attacker never has to read the response. The stated reason for skipping
  # the token ("these are JSON endpoints") was simply not enforced anywhere, so
  # it described our callers rather than our acceptance.
  #
  #   1. JSON only. A POST whose Content-Type is not application/json is
  #      refused with 415 before any parameter is read. That makes the premise
  #      true instead of merely customary — and it is the half that actually
  #      closes the hole, because a cross-site HTML <form> cannot send
  #      application/json (the three form enctypes are the only ones available
  #      to it, and reaching for fetch/XHR instead puts the request under CORS).
  #
  #   2. Origin, when the browser sends one. Same-origin POSTs do carry an
  #      Origin header (the Fetch spec sends it for every method other than
  #      GET/HEAD), so a mismatch is a real signal — but a MISSING one is not,
  #      and must not be: non-browser callers (curl, a monitor) send neither
  #      Origin nor Referer, and we have no interest in blocking them. So the
  #      rule is "if present it must be ours", never "it must be present".
  #      Host is compared, not the full origin: behind kamal-proxy the scheme
  #      the app sees and the scheme the browser used need not agree, and the
  #      Host header for a cross-site request is set by the browser from OUR
  #      URL — an attacker's page can forge its own Origin value but cannot
  #      make the browser claim our Origin.
  #
  # Both guards are on the base class, so a fourth /api/ endpoint inherits them
  # rather than having to remember them.
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :set_locale

    before_action :require_json_request
    before_action :require_own_origin

    private

    def require_json_request
      return if request.get? || request.head?
      return if request.content_mime_type == :json

      Rails.logger.info("[api] refused #{request.path}: content-type #{request.content_type.inspect}")
      head :unsupported_media_type
    end

    def require_own_origin
      stated = request.headers["Origin"].presence || request.headers["Referer"].presence
      return if stated.blank?
      return if same_host?(stated)

      Rails.logger.info("[api] refused #{request.path}: origin #{stated.inspect} is not #{request.host.inspect}")
      head :forbidden
    end

    # "null" (a sandboxed iframe or a redirect-stripped origin) is deliberately
    # NOT treated as absent — it is a browser telling us the opposite of ours.
    def same_host?(stated)
      URI.parse(stated).host == request.host
    rescue URI::InvalidURIError
      false
    end

    # ── Rate limiting ──────────────────────────────────────────────────────────
    #
    # One window-bucketed counter, used by every /api/ endpoint that has a
    # ceiling, so there is one place where the counting is either atomic or not.
    #
    # It replaces `read → +1 → write`, which is a lost-update race: two requests
    # that read the same 2 both write 3 and both are allowed. Solid Cache being
    # shared across Puma workers does not help with that — a shared store is
    # what makes the two readers see the same stale value in the first place.
    #
    # `Rails.cache.increment` is atomic in every store this app can be
    # configured with, and creates the key when it is missing, so no
    # write-then-increment dance is needed:
    #
    #   * :solid_cache_store — SELECT … FOR UPDATE inside a transaction
    #     (solid_cache-1.0.10 app/models/solid_cache/entry.rb:70 `lock_and_write`),
    #     and a missing/expired entry becomes `Entry.new(amount)`
    #     (lib/solid_cache/store/api.rb:174). Production.
    #   * :memory_store — `synchronize { … }`, missing key → `write(amount)`
    #     (activesupport cache/memory_store.rb:243 `modify_value`). Development,
    #     and what CacheStoreHelper installs for the cap tests.
    #   * :null_store — returns nil, so `to_i` is 0 and no cap ever fires
    #     (activesupport cache/null_store.rb). The test default; the
    #     "cap does not fire without a cache that remembers" tests assert
    #     exactly this, and they keep asserting it.
    #
    # The expiry is set when the key is created and then left alone by later
    # increments (both stores preserve `expires_at`), which is what we want:
    # the key already carries its window in its name, so a sliding TTL would
    # only keep a dead bucket alive.
    #
    # Returns true when this request is over the limit.
    def over_limit?(key, limit:, window:)
      bucket = Time.current.to_i / window.to_i
      Rails.cache.increment("#{key}:#{bucket}", 1, expires_in: window * 2).to_i > limit
    end
  end
end
