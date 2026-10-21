require "test_helper"
require_relative "../../support/cache_store_helper"

# What this endpoint stores is the whole security property, so the tests are
# written from the outside: a request goes in, and the assertion is on the row
# count and on the stored hash — never on the controller's internals.
class Api::SafeEventsControllerTest < ActionDispatch::IntegrationTest
  include CacheStoreHelper

  setup { SafeEvent.delete_all }

  def post_event(payload)
    post "/api/safe_events", params: payload.to_json,
                             headers: { "CONTENT_TYPE" => "application/json" }
  end

  test "stores a whitelisted event" do
    assert_difference "SafeEvent.count", 1 do
      post_event(name: "doc_class", props: { doc_class: "shikaku_kakuninsho", locale: "ja", from: "nyusatsu" })
    end

    assert_response :no_content
    event = SafeEvent.last
    assert_equal "doc_class", event.name
    assert_equal({ "doc_class" => "shikaku_kakuninsho", "locale" => "ja", "from" => "nyusatsu" }, event.props)
  end

  test "rejects an event name that is not on the whitelist" do
    assert_no_difference "SafeEvent.count" do
      post_event(name: "keystroke", props: { locale: "ja" })
    end

    assert_response :unprocessable_entity
  end

  test "rejects a key that is not allowed for that event" do
    # `format` is meaningful on a download, not on a landing view.
    assert_no_difference "SafeEvent.count" do
      post_event(name: "landing_view", props: { from: "nyusatsu", format: "pdf" })
    end

    assert_response :unprocessable_entity
  end

  test "rejects a value that is not on the whitelist" do
    assert_no_difference "SafeEvent.count" do
      post_event(name: "doc_class", props: { doc_class: "passport_scan", locale: "ja" })
    end

    assert_response :unprocessable_entity
  end

  # The point of the endpoint is that these cannot be smuggled in. Each of
  # these is a key a well-meaning future change might add; all must bounce.
  test "rejects free text, file names, coordinates and identifiers" do
    [
      { name: "upload", props: { ext: "pdf", filename: "健康保険証.pdf" } },
      { name: "upload", props: { ext: "pdf", text: "被保険者番号 1234567" } },
      { name: "download", props: { format: "pdf", box: "12,40,180,22" } },
      { name: "landing_view", props: { from: "nyusatsu", ip: "203.0.113.9" } },
      { name: "landing_view", props: { from: "nyusatsu", visitor_id: "abc123" } },
      { name: "upload", props: { ext: "pdf", pages: "17" } }
    ].each do |payload|
      assert_no_difference "SafeEvent.count", "#{payload[:props].keys.last} was accepted" do
        post_event(payload)
      end
      assert_response :unprocessable_entity
    end
  end

  test "a nested value cannot sneak past the value whitelist" do
    assert_no_difference "SafeEvent.count" do
      post_event(name: "doc_class", props: { doc_class: { evil: "shikaku_kakuninsho" } })
    end

    assert_response :unprocessable_entity
  end

  test "an event with no props at all is stored" do
    assert_difference "SafeEvent.count", 1 do
      post_event(name: "upload")
    end

    assert_response :no_content
    assert_equal({}, SafeEvent.last.props)
  end

  # Not a style assertion — it is the promise. If any of these columns ever
  # appears, the privacy claim on /safe/ and the three landing pages is false.
  test "the table has no column that could identify a visitor" do
    forbidden = %w[ip ip_address ip_hash remote_ip user_agent session_id visitor_id fingerprint cookie referer email]
    present = SafeEvent.column_names & forbidden
    assert_empty present, "safe_events must not carry #{present.join(', ')}"
    assert_equal %w[created_at id name props], SafeEvent.column_names.sort
  end

  test "the whole endpoint is capped and the cap is not per-visitor" do
    with_memory_cache do
      limit = Api::SafeEventsController::THROTTLE_LIMIT
      # Prime the bucket to the limit rather than issuing hundreds of requests:
      # the key shape is part of the contract being asserted, and a test that
      # only counts requests would still pass if the key gained an IP.
      bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
      Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)

      assert_no_difference "SafeEvent.count" do
        post_event(name: "landing_view", props: { from: "nyusatsu" })
      end
      assert_response :too_many_requests
    end
  end

  # Guards the previous test against the null store. If the cap were asserted
  # under the test default, the counter would write to a store that forgets and
  # the limit could never be reached — green regardless of the code.
  test "the cap does not fire without a cache that remembers" do
    limit = Api::SafeEventsController::THROTTLE_LIMIT
    bucket = Time.current.to_i / Api::SafeEventsController::THROTTLE_WINDOW.to_i
    Rails.cache.write("safe_events:all:#{bucket}", limit, expires_in: 2.minutes)

    assert_difference "SafeEvent.count", 1 do
      post_event(name: "landing_view", props: { from: "nyusatsu" })
    end
    assert_response :no_content
  end
end
