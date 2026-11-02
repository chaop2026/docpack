require "test_helper"

# S11 item 6 — IndexNow.
#
# The problem, measured on 2026-11-02: Google had every SafeFile JP URL as
# "Discovered – currently not indexed" and Bing — which is what ChatGPT search
# and Copilot read — did not know the site existed. IndexNow is one POST that
# removes "nobody told the engine" from the list of reasons a page is missing.
#
# Three things are asserted, and the first two are the ones that fail quietly:
#
#   1. The key is read from ENV and the key FILE is served from the same value,
#      so the two cannot disagree. No key → 404, wrong key → 404.
#   2. Dry run is the default posture, and a submission failure never costs the
#      publish. A job that turned a successful publish into a failed run
#      because a third-party endpoint was down would be strictly worse than
#      not pinging at all.
#   3. Nothing logs the key.
class IndexNowTest < ActionDispatch::IntegrationTest
  KEY = "s11testkeyabcdef0123456789abcdef".freeze

  # ENV is process-global; every test restores exactly what it found, including
  # keys that were absent (`ENV[k] = nil` sets "" — delete is what is wanted).
  def with_env(pairs)
    before = pairs.keys.to_h { |k| [ k, ENV[k] ] }
    pairs.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    before.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    # Severity included. The default formatter writes the message only, which
    # makes a `/ERROR/` assertion pass at any level — the vacuous-assertion
    # trap this repository already hit once in the job tests.
    logger.formatter = proc { |sev, _t, _p, msg| "#{sev} #{msg}\n" }
    yield logger
    io.string
  end

  # ── 1. the key file ───────────────────────────────────────────────────────

  test "the key file is served from ENV at /<key>.txt" do
    with_env("INDEXNOW_KEY" => KEY) do
      get "/#{KEY}.txt"
      assert_response :success
      assert_equal "text/plain", response.media_type
      assert_equal KEY, response.body.strip,
                   "IndexNow verifies ownership by reading this back; the body IS the key"
    end
  end

  test "a wrong key is a 404, and so is any key when none is configured" do
    with_env("INDEXNOW_KEY" => KEY) do
      get "/0000000000000000000000000000000.txt"
      assert_response :not_found
    end

    with_env("INDEXNOW_KEY" => nil) do
      get "/#{KEY}.txt"
      assert_response :not_found,
                      "with no key configured there is nothing to verify, and the route must not " \
                      "turn every /<something>.txt into a 200"
    end
  end

  test "the key route plants no cookie, even when asked to" do
    # ApplicationController#set_locale writes a one-year `locale` cookie
    # whenever params[:locale] is present — and params includes the query
    # string. A crawler fetching this file with ?locale=ja would be handed an
    # identifier. Exactly the finding from S6b, in a new controller.
    with_env("INDEXNOW_KEY" => KEY) do
      get "/#{KEY}.txt?locale=ja"
      assert_response :success
      assert_nil response.headers["Set-Cookie"], "the key file set a cookie"
    end
  end

  test "the route does not shadow the static text files" do
    # robots.txt and llms.txt are answered by ActionDispatch::Static, which
    # runs in front of the router — asserted rather than assumed, because the
    # route added in S11 is the only dynamic top-level one in routes.rb.
    with_env("INDEXNOW_KEY" => KEY) do
      get "/robots.txt"
      assert_response :success
      assert_includes response.body, "Sitemap:"

      get "/llms.txt"
      assert_response :success
      assert_includes response.body, "SafeFile"
    end
  end

  test "key_location is derived from the key, not configured separately" do
    with_env("INDEXNOW_KEY" => KEY) do
      assert_equal "https://slimfile.net/#{KEY}.txt",
                   IndexNow.key_location("https://slimfile.net")
      assert_equal "https://slimfile.net/#{KEY}.txt",
                   IndexNow.key_location("https://slimfile.net/"),
                   "a trailing slash on the base URL must not produce a double slash"
    end
    with_env("INDEXNOW_KEY" => nil) { assert_nil IndexNow.key_location("https://slimfile.net") }
  end

  # ── 2. dry run and failure ────────────────────────────────────────────────

  test "no key means dry run, and the flag forces it even when a key is present" do
    with_env("INDEXNOW_KEY" => nil, "INDEXNOW_DRY_RUN" => nil) do
      assert IndexNow.dry_run?
    end
    with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => "1") do
      assert IndexNow.dry_run?, "the flag must beat the key"
    end
    # The inverse, so the two above are not passing for the wrong reason.
    with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => nil) do
      refute IndexNow.dry_run?,
             "if the live configuration cannot be reached, every assertion above is vacuous"
    end
  end

  test "a dry run sends nothing and says what it would have sent" do
    calls = []
    out = capture_log do |logger|
      with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => "1") do
        result = IndexNow.submit([ "https://slimfile.net/ja/blog/x" ],
                                 logger: logger,
                                 http: ->(url, payload) { calls << [ url, payload ]; 200 })
        assert_equal :dry_run, result[:status]
        assert_equal [ "https://slimfile.net/ja/blog/x" ], result[:urls]
      end
    end

    assert_empty calls, "a dry run must not call the endpoint"
    assert_includes out, "DRY RUN"
    assert_includes out, "https://slimfile.net/ja/blog/x",
                    "the log has to name the URL, or a dry run proves nothing about what would be sent"
  end

  test "a live submission posts the key and the derived keyLocation" do
    calls = []
    with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => nil) do
      result = IndexNow.submit([ "https://slimfile.net/ja/blog/x" ],
                               logger: nil,
                               http: ->(url, payload) { calls << [ url, payload ]; 200 })
      assert_equal :sent, result[:status]
      assert_equal 200, result[:code]
    end

    assert_equal 1, calls.length
    url, payload = calls.first
    assert_equal IndexNow::ENDPOINT, url
    assert_equal "slimfile.net", payload["host"]
    assert_equal KEY, payload["key"]
    assert_equal "https://slimfile.net/#{KEY}.txt", payload["keyLocation"]
    assert_equal [ "https://slimfile.net/ja/blog/x" ], payload["urlList"]
  end

  test "202 is accepted — it means the key has not been validated yet" do
    with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => nil) do
      result = IndexNow.submit([ "https://slimfile.net/a" ], logger: nil, http: ->(*) { 202 })
      assert_equal :sent, result[:status], "202 is normal on the first submission after a deploy"
    end
  end

  test "a refusal and a raised exception both return a status instead of raising" do
    with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => nil) do
      refused = IndexNow.submit([ "https://slimfile.net/a" ], logger: nil, http: ->(*) { 403 })
      assert_equal :failed, refused[:status]
      assert_equal 403, refused[:code]

      exploded = IndexNow.submit([ "https://slimfile.net/a" ], logger: nil,
                                 http: ->(*) { raise Errno::ECONNREFUSED })
      assert_equal :failed, exploded[:status]
      assert_includes exploded[:error], "Errno::ECONNREFUSED"
    end
  end

  test "an empty list is skipped rather than posted" do
    calls = []
    result = IndexNow.submit([ nil, "" ], logger: nil, http: ->(*) { calls << 1; 200 })
    assert_equal :skipped, result[:status]
    assert_empty calls
  end

  # ── 3. the key never reaches a log ────────────────────────────────────────

  test "nothing logs the key value" do
    [ [ "1", ->(*) { 200 } ], [ nil, ->(*) { 403 } ], [ nil, ->(*) { raise "boom #{KEY[0, 4]}x" } ] ]
      .each do |flag, http|
      out = capture_log do |logger|
        with_env("INDEXNOW_KEY" => KEY, "INDEXNOW_DRY_RUN" => flag) do
          IndexNow.submit([ "https://slimfile.net/a" ], logger: logger, http: http)
        end
      end
      refute_includes out, KEY, "the key appeared in a log line (dry_run=#{flag.inspect})"
    end
  end

  test "the report says whether a key is present without printing it" do
    with_env("INDEXNOW_KEY" => KEY) do
      r = IndexNow.report
      assert_equal true, r["present"]
      assert_equal KEY.length, r["length"]
      refute_includes r.to_s, KEY
    end
  end

  test "the key is not committed anywhere in the repository" do
    # The reason it is served from ENV rather than from public/<key>.txt. This
    # repository is public and its history is permanent, so a committed key
    # could not be rotated. Checked as a property of the tree rather than as a
    # promise in a comment.
    offenders = %w[public config app lib].flat_map do |dir|
      Dir[Rails.root.join(dir, "**", "*").to_s].select { |f| File.file?(f) && f.end_with?(".txt") }
    end
    offenders.each do |f|
      refute_match(/\AINDEXNOW/i, File.basename(f),
                   "#{f} looks like a committed IndexNow key file")
    end

    # And no 32-hex-ish literal assigned to the name anywhere in the tracked
    # Ruby/YAML/JS we control.
    sources = Dir[Rails.root.join("{app,lib,config,public}", "**", "*.{rb,yml,js,erb}").to_s]
    sources.each do |f|
      body = File.read(f)
      next unless body.include?("INDEXNOW_KEY")

      refute_match(/INDEXNOW_KEY\s*[:=]\s*["']?[A-Za-z0-9]{8,}/, body,
                   "#{f} assigns a literal value to INDEXNOW_KEY")
    end
  end
end
