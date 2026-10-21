require "test_helper"
require_relative "../../support/cache_store_helper"

class Api::JpPilotControllerTest < ActionDispatch::IntegrationTest
  include CacheStoreHelper

  VALID = {
    company: "○○建設株式会社",
    industry: "construction",
    monthly_count: "3-5",
    authority: "○○県 ○○市",
    email: "office@example.co.jp",
    from: "nyusatsu"
  }.freeze

  setup do
    JpPilotRequest.delete_all
    ActionMailer::Base.deliveries.clear
  end

  def post_pilot(payload)
    post "/api/jp_pilot", params: payload.to_json,
                          headers: { "CONTENT_TYPE" => "application/json" }
  end

  test "stores a valid request and notifies" do
    assert_difference "JpPilotRequest.count", 1 do
      perform_enqueued_jobs { post_pilot(VALID) }
    end

    assert_response :created
    req = JpPilotRequest.last
    assert_equal "○○建設株式会社", req.company
    assert_equal "nyusatsu", req.from

    # The mail must actually render and send, not merely enqueue — a mailer that
    # raises on render only shows up when the job runs.
    mail = ActionMailer::Base.deliveries.last
    assert_not_nil mail
    assert_equal "[SafeFile JP] パイロット申込", mail.subject
  end

  # The honeypot must be indistinguishable from success on the wire. A
  # distinguishable rejection hands a spam script a free oracle, so the only
  # observable difference is that no row exists.
  test "honeypot submissions are dropped but answered like a success" do
    assert_no_difference "JpPilotRequest.count" do
      post_pilot(VALID.merge(website: "https://spam.example.com"))
    end

    assert_response :created
    assert_equal({ "ok" => true }, JSON.parse(response.body))
    assert_empty ActionMailer::Base.deliveries
  end

  test "an empty honeypot field is not treated as spam" do
    # The field is rendered on the page, so a real browser always posts it —
    # as an empty string. If that counted as filled, the form would reject
    # every genuine submission while reporting success, and the only symptom
    # would be an admin list that never grows.
    assert_difference "JpPilotRequest.count", 1 do
      post_pilot(VALID.merge(website: ""))
    end

    assert_response :created
  end

  test "rejects a malformed email" do
    assert_no_difference "JpPilotRequest.count" do
      post_pilot(VALID.merge(email: "office@example"))
    end

    assert_response :unprocessable_entity
    assert JSON.parse(response.body)["errors"].any?
  end

  test "rejects an industry outside the select options" do
    assert_no_difference "JpPilotRequest.count" do
      post_pilot(VALID.merge(industry: "<script>alert(1)</script>"))
    end

    assert_response :unprocessable_entity
  end

  test "rejects an over-long company name" do
    assert_no_difference "JpPilotRequest.count" do
      post_pilot(VALID.merge(company: "あ" * 121))
    end

    assert_response :unprocessable_entity
  end

  test "an unrecognised from value falls back to direct rather than failing" do
    # `from` is a marketing attribution hint, not something the applicant typed.
    # A stale or hand-edited link must not cost a real sign-up.
    assert_difference "JpPilotRequest.count", 1 do
      post_pilot(VALID.merge(from: "../../etc/passwd"))
    end

    assert_response :created
    assert_equal "direct", JpPilotRequest.last.from
  end

  test "caps submissions per IP within the window" do
    with_memory_cache do
      limit = Api::JpPilotController::RATE_LIMIT
      limit.times { |i| post_pilot(VALID.merge(email: "a#{i}@example.co.jp")) }
      assert_equal limit, JpPilotRequest.count

      assert_no_difference "JpPilotRequest.count" do
        post_pilot(VALID.merge(email: "over@example.co.jp"))
      end
      assert_response :too_many_requests
    end
  end

  # Guards the test above against the null store the test env sets by default:
  # with a cache that forgets, the counter never reaches the limit and the cap
  # assertion would be green no matter what the controller did.
  test "the cap does not fire without a cache that remembers" do
    limit = Api::JpPilotController::RATE_LIMIT
    (limit + 2).times { |i| post_pilot(VALID.merge(email: "b#{i}@example.co.jp")) }

    assert_equal limit + 2, JpPilotRequest.count
    assert_response :created
  end

  test "a failed notification does not lose the sign-up" do
    # The row is the record of truth; SMTP has failed in this app before
    # (2026-04-07). A mail failure must not turn into a 422 the applicant sees.
    JpPilotMailer.stub(:pilot_requested, ->(*) { raise "smtp down" }) do
      assert_difference "JpPilotRequest.count", 1 do
        post_pilot(VALID)
      end
    end

    assert_response :created
  end
end
