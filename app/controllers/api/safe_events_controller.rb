# app/controllers/api/safe_events_controller.rb
#
# Anonymous, category-only usage counters for SafeFile.
#
#   POST /api/safe_events
#   { "name": "doc_class", "props": { "doc_class": "shikaku_kakuninsho", "locale": "ja" } }
#   → 204 No Content
#
# The browser sends these with navigator.sendBeacon and never reads the
# response, so the status code exists for our logs and tests, not for the page.
#
# What this endpoint deliberately does NOT do:
#
#   * It does not look at request.remote_ip. Not to store it, not to hash it,
#     not to rate-limit on it. A per-IP counter is a per-visitor identifier
#     however it is spelled, and /safe/ promises the processing screen carries
#     no tracking. The abuse ceiling is instead a flat per-minute cap on the
#     whole endpoint (see THROTTLE_*), which is blind to who is calling.
#   * It does not set or read a cookie, and it does not touch the session.
#   * It stores nothing that is not on SafeEvent's whitelist. The model owns
#     that list; this controller just refuses what the model will not take.
module Api
  class SafeEventsController < BaseController
    # A global ceiling, not a per-client one. 600 events/minute is far above
    # what organic use produces and still bounds a flood to something the table
    # can absorb. It cannot single out an abuser — that is the trade we are
    # making on purpose, and the reason the cap is generous.
    THROTTLE_LIMIT  = 600
    THROTTLE_WINDOW = 1.minute

    # Bounds the work per request. Not the gate — SafeEvent::KEYS is.
    MAX_KEYS = 12

    def create
      return head(:too_many_requests) if throttled?

      raw = permitted_props
      return head(:unprocessable_entity) if raw.nil?

      props = SafeEvent.sanitize(params[:name], raw)
      return head(:unprocessable_entity) if props.nil?

      SafeEvent.create!(name: params[:name].to_s, props: props)
      head :no_content
    rescue ActiveRecord::RecordInvalid
      # sanitize already rejected everything the model would reject, so this is
      # a genuine surprise. 422 rather than 500: the client cannot fix it, but
      # a 500 would page us for a counter.
      head :unprocessable_entity
    end

    private

    # Hands SafeEvent.sanitize exactly what the client sent — including keys we
    # do not know — so an unknown key is REJECTED rather than quietly dropped.
    #
    # Filtering to the known keys here would have been the obvious move and is
    # the wrong one: the request would then succeed while losing a field, and
    # since sendBeacon discards the response, a client that drifts would look
    # healthy from both sides. Values are stringified by sanitize, so a nested
    # hash or array arrives as a string that is not on any whitelist and fails
    # the same way. Returns nil when the request is already refusable.
    def permitted_props
      raw = params[:props]
      return {} unless raw.respond_to?(:each_pair)
      return nil if raw.keys.size > MAX_KEYS

      raw.each_pair.to_h { |k, v| [ k.to_s, v ] }
    end

    # Window-bucketed counter in Rails.cache. No request attribute is part of
    # the key — that is the point of this endpoint, not an oversight. Atomic:
    # see Api::BaseController#over_limit?.
    def throttled?
      over_limit?("safe_events:all", limit: THROTTLE_LIMIT, window: THROTTLE_WINDOW)
    end
  end
end
