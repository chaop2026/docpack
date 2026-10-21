require "test_helper"

# The /api/ endpoints skip CSRF verification. The stated reason was "they are
# JSON endpoints called with fetch/sendBeacon" — which described our callers,
# not our acceptance: nothing stopped a form-urlencoded POST from somewhere
# else, and Rails builds the same `params` from one. /api/jp_pilot would have
# written a row and sent mail for it, and the attacker never needed to read the
# response.
#
# These tests are the enforcement of that premise. They are written against all
# three endpoints rather than one, because the guard lives on Api::BaseController
# and a fourth endpoint must inherit it rather than remember it.
class Api::BaseControllerTest < ActionDispatch::IntegrationTest
  # Each endpoint with a payload that WOULD be accepted, so a rejection can only
  # come from the guard under test and not from validation.
  ENDPOINTS = [
    [ "/api/jp_pilot",
      { company: "x", industry: "other", monthly_count: "1-2", email: "a@b.co.jp" },
      :created ],
    [ "/api/safe_events",
      { name: "landing_view", props: { from: "direct", locale: "ja" } },
      :no_content ],
    # safe_scan with no text and no image answers 400 "empty" BEFORE any call to
    # Anthropic, so this exercises the filters without spending a token.
    [ "/api/safe_scan", {}, :bad_request ]
  ].freeze

  OWN_ORIGIN = "http://www.example.com".freeze   # IntegrationTest's default host

  setup do
    JpPilotRequest.delete_all
    SafeEvent.delete_all
    ActionMailer::Base.deliveries.clear
  end

  def rows
    JpPilotRequest.count + SafeEvent.count
  end

  # The one that actually closes the hole. A cross-site <form> can only send
  # one of the three form enctypes; reaching for fetch/XHR to send JSON instead
  # puts the request under CORS, where our Origin check is not even needed.
  test "a form-urlencoded POST is refused with 415 and writes nothing" do
    ENDPOINTS.each do |path, payload, _ok|
      assert_no_difference "JpPilotRequest.count + SafeEvent.count" do
        post path, params: payload
      end
      assert_response :unsupported_media_type, "#{path} accepted form-urlencoded"
    end
    assert_empty ActionMailer::Base.deliveries
  end

  test "a multipart POST is refused with 415" do
    # A raw body, not `params:` — the integration session would append its own
    # boundary to the content type and Rack would reject the request before any
    # of our filters ran, which would make this test green for a reason that has
    # nothing to do with the guard.
    post "/api/jp_pilot",
         params: "------x\r\nContent-Disposition: form-data; name=\"company\"\r\n\r\nx\r\n------x--\r\n",
         headers: { "CONTENT_TYPE" => "multipart/form-data; boundary=----x" }
    assert_response :unsupported_media_type
  end

  test "a POST with no Content-Type at all is refused with 415" do
    ENDPOINTS.each do |path, payload, _ok|
      post path, params: payload.to_json, headers: { "CONTENT_TYPE" => nil }
      assert_response :unsupported_media_type, "#{path} accepted a typeless body"
    end
  end

  test "text/plain is refused — sendBeacon's default for a string body" do
    # navigator.sendBeacon(url, "string") sends text/plain;charset=UTF-8. Both
    # callers wrap the body in a Blob with type application/json instead, and
    # that is now a requirement rather than a habit.
    post "/api/safe_events", params: { name: "landing_view", props: { from: "direct" } }.to_json,
                             headers: { "CONTENT_TYPE" => "text/plain;charset=UTF-8" }
    assert_response :unsupported_media_type
  end

  test "application/json with a charset parameter is accepted" do
    ENDPOINTS.each do |path, payload, expected|
      post path, params: payload.to_json,
                 headers: { "CONTENT_TYPE" => "application/json; charset=utf-8" }
      assert_response expected, "#{path} rejected a charset-qualified JSON body"
    end
  end

  test "JSON from another origin is refused with 403 and writes nothing" do
    ENDPOINTS.each do |path, payload, _ok|
      assert_no_difference "JpPilotRequest.count + SafeEvent.count" do
        post path, params: payload.to_json,
                   headers: { "CONTENT_TYPE" => "application/json",
                              "HTTP_ORIGIN" => "https://spam.example.com" }
      end
      assert_response :forbidden, "#{path} accepted a foreign Origin"
    end
    assert_empty ActionMailer::Base.deliveries
  end

  test "a foreign Referer is refused even with no Origin header" do
    post "/api/jp_pilot", params: { company: "x", industry: "other", monthly_count: "1-2", email: "a@b.co.jp" }.to_json,
                          headers: { "CONTENT_TYPE" => "application/json",
                                     "HTTP_REFERER" => "https://spam.example.com/page" }
    assert_response :forbidden
  end

  # "null" is a sandboxed iframe or an origin stripped by a redirect. It is a
  # browser saying "not yours", which is the opposite of saying nothing.
  test "Origin: null is refused, not treated as absent" do
    post "/api/safe_events", params: { name: "landing_view", props: { from: "direct" } }.to_json,
                             headers: { "CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => "null" }
    assert_response :forbidden
  end

  test "our own Origin is accepted" do
    ENDPOINTS.each do |path, payload, expected|
      post path, params: payload.to_json,
                 headers: { "CONTENT_TYPE" => "application/json", "HTTP_ORIGIN" => OWN_ORIGIN }
      assert_response expected, "#{path} rejected its own origin"
    end
  end

  test "our own Referer with no Origin is accepted" do
    post "/api/safe_events", params: { name: "landing_view", props: { from: "direct" } }.to_json,
                             headers: { "CONTENT_TYPE" => "application/json",
                                        "HTTP_REFERER" => "#{OWN_ORIGIN}/safe/jp/nyusatsu/" }
    assert_response :no_content
  end

  # A missing Origin must stay allowed. curl, a monitor and any non-browser
  # caller send neither header, and refusing them buys nothing: the thing the
  # Origin check is for is a browser being driven by someone else's page, and a
  # browser always tells us. Turning "absent" into a rejection would also be
  # invisible to the page — sendBeacon never reads the response.
  test "no Origin and no Referer is accepted" do
    ENDPOINTS.each do |path, payload, expected|
      post path, params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      assert_response expected, "#{path} rejected a header-less caller"
    end
  end

  # Guards every assertion above: if the payloads had drifted out of validity,
  # the 415/403 tests would all pass for the wrong reason.
  test "the payloads used above are genuinely acceptable" do
    assert_difference "JpPilotRequest.count", 1 do
      post "/api/jp_pilot", params: ENDPOINTS[0][1].to_json,
                            headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :created

    assert_difference "SafeEvent.count", 1 do
      post "/api/safe_events", params: ENDPOINTS[1][1].to_json,
                               headers: { "CONTENT_TYPE" => "application/json" }
    end
    assert_response :no_content
  end
end
