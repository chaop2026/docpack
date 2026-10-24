require "net/http"
require "uri"
require "json"
require "openssl"
require "base64"
require "securerandom"

# Minimal X (Twitter) API v2 client: OAuth 1.0a user-context signing over
# Net::HTTP. No gem.
#
# ── Why no gem ──────────────────────────────────────────────────────────────
#
# This app needs exactly three calls — upload a medium, post a tweet, post a
# reply — and adding an OAuth gem to the production image for three calls means
# carrying its whole surface (and its transitive dependencies) through every
# deploy and every security scan. The signing algorithm is forty lines and is
# specified; it does not drift.
#
# ── DRY RUN IS THE DEFAULT POSTURE ──────────────────────────────────────────
#
# `X_API_DRY_RUN=1`, or any missing credential, makes every write a log line and
# nothing else. It stays that way until somebody has confirmed, on the real
# account, the plan tier, the monthly write cap and whether media upload is
# permitted at all. Strategy v3 asserted «Free tier, 1,500 writes/month»; the
# cross-review (Q3) established that this is NOT a safe premise — X's current
# free access is metered differently and "Legacy Free" is a separate thing. An
# automation that discovers its write cap by exhausting it does so by posting
# half a thread.
#
# ── What this class does NOT do ─────────────────────────────────────────────
#
# It does not retry, does not decide what is safe to re-send, and does not
# interpret a timeout. Those are XPublishJob's decisions, because only the job
# knows which tweets already have ids. This class reports what happened as
# precisely as it can — including the one answer that matters most, "I do not
# know whether that was posted".
class XClient
  # Raised for a response that says the request was understood and rejected.
  # Deterministic: retrying sends the same bytes and gets the same answer.
  class ClientError < StandardError
    attr_reader :status, :body
    def initialize(status, body)
      @status = status
      @body = body
      super("X API #{status}: #{body.to_s.first(300)}")
    end
  end

  # Raised when the request may or may not have been carried out: a timeout, a
  # reset connection, a 5xx. The ONLY correct response is to stop and have a
  # person look, which is why it is a distinct class — re-sending a tweet that
  # may already exist is how a thread gets posted twice.
  class IndeterminateError < StandardError; end

  TWEETS_URL      = "https://api.twitter.com/2/tweets".freeze
  MEDIA_V2_URL    = "https://api.twitter.com/2/media/upload".freeze
  MEDIA_V11_URL   = "https://upload.twitter.com/1.1/media/upload.json".freeze

  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 45

  def self.dry_run?
    ENV["X_API_DRY_RUN"] == "1" || !credentials_present?
  end

  def self.credentials_present?
    %w[X_API_KEY X_API_SECRET X_ACCESS_TOKEN X_ACCESS_SECRET].all? { |k| ENV[k].present? }
  end

  # Never the values. `.present?` and `.length` only — a log line that echoes a
  # token is a leak with a long tail.
  def self.credential_report
    %w[X_API_KEY X_API_SECRET X_ACCESS_TOKEN X_ACCESS_SECRET].to_h do |k|
      [ k, { "present" => ENV[k].present?, "length" => ENV[k].to_s.length } ]
    end
  end

  def initialize(logger: Rails.logger)
    @logger = logger
  end

  def dry_run?
    self.class.dry_run?
  end

  # → tweet id (String). In dry run → a "dry-" pseudo-id so the job's own state
  # machine can be exercised end to end without posting.
  def post_tweet(text:, media_id: nil, reply_to: nil)
    body = { text: text }
    body[:media] = { media_ids: [ media_id ] } if media_id
    body[:reply] = { in_reply_to_tweet_id: reply_to } if reply_to

    if dry_run?
      @logger.info("[X DRY RUN] POST /2/tweets #{body.to_json.first(400)}")
      return "dry-#{Digest::SHA256.hexdigest(text)[0, 16]}"
    end

    json = post_json(TWEETS_URL, body)
    id = json.dig("data", "id")
    raise IndeterminateError, "POST /2/tweets returned 2xx with no data.id: #{json.to_json.first(200)}" if id.blank?

    id.to_s
  end

  # → media id (String).
  #
  # v2 first, v1.1 as the fallback. The endpoints have been migrating and which
  # one an app may use depends on its access level, so both are tried; if
  # NEITHER works the caller is told, and XPublishJob then fails the thread
  # rather than posting a thread whose first tweet has lost its demo. Posting
  # the text alone would be a quiet downgrade of the thing the thread is for.
  def upload_media(path:, content_type:)
    if dry_run?
      @logger.info("[X DRY RUN] media upload #{File.basename(path)} (#{content_type}, #{File.size(path)} bytes)")
      return "dry-media-#{File.basename(path)}"
    end

    begin
      multipart_upload(MEDIA_V2_URL, path, content_type).then do |json|
        id = json["id"] || json.dig("data", "id") || json["media_id_string"]
        return id.to_s if id.present?
        raise ClientError.new(200, "v2 media upload returned no id: #{json.to_json.first(200)}")
      end
    rescue ClientError => e
      @logger.warn("XClient: v2 media upload failed (#{e.status}) — trying v1.1")
      json = multipart_upload(MEDIA_V11_URL, path, content_type)
      id = json["media_id_string"] || json["media_id"]
      raise ClientError.new(200, "v1.1 media upload returned no id") if id.blank?

      id.to_s
    end
  end

  private

  def post_json(url, body)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    # OAuth 1.0a over a JSON body: the body is NOT part of the signature base
    # string (only query parameters are), which is why no params are passed in.
    req["Authorization"] = oauth_header("POST", url, {})
    req.body = body.to_json
    perform(uri, req)
  end

  def multipart_upload(url, path, content_type)
    uri = URI(url)
    boundary = "----XClient#{SecureRandom.hex(12)}"
    payload = +""
    payload << "--#{boundary}\r\n"
    payload << "Content-Disposition: form-data; name=\"media\"; filename=\"#{File.basename(path)}\"\r\n"
    payload << "Content-Type: #{content_type}\r\n\r\n"
    payload << File.binread(path)
    payload << "\r\n--#{boundary}--\r\n"

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
    req["Authorization"] = oauth_header("POST", url, {})
    req.body = payload
    perform(uri, req)
  end

  # The error classification lives here, in one place, because the whole safety
  # argument for XPublishJob rests on it:
  #
  #   2xx                  → parsed JSON
  #   4xx (not 429)        → ClientError        deterministic, do not retry
  #   429 / 5xx / timeout  → IndeterminateError may have happened, stop
  #
  # 429 counts as indeterminate on purpose. A rate-limit response means this
  # request did not go through, but it arrives when we are at the edge of a
  # quota we have not confirmed the size of — the right move is to stop and look
  # rather than to keep probing.
  def perform(uri, req)
    res = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
                          open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(req)
    end

    code = res.code.to_i
    if code.between?(200, 299)
      res.body.present? ? JSON.parse(res.body) : {}
    elsif code == 429 || code >= 500
      raise IndeterminateError, "X API #{code} — may or may not have been carried out: #{res.body.to_s.first(300)}"
    else
      raise ClientError.new(code, res.body)
    end
  rescue JSON::ParserError => e
    raise IndeterminateError, "X API returned 2xx with unparseable body: #{e.message}"
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::EPIPE, EOFError,
         OpenSSL::SSL::SSLError, SocketError => e
    raise IndeterminateError, "#{e.class}: #{e.message}"
  end

  # ── OAuth 1.0a (HMAC-SHA1) ─────────────────────────────────────────────────

  def oauth_header(method, url, params)
    oauth = {
      "oauth_consumer_key" => ENV.fetch("X_API_KEY"),
      "oauth_nonce" => SecureRandom.hex(16),
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => Time.now.to_i.to_s,
      "oauth_token" => ENV.fetch("X_ACCESS_TOKEN"),
      "oauth_version" => "1.0"
    }

    oauth["oauth_signature"] = signature(method, url, oauth.merge(params))
    "OAuth " + oauth.sort.map { |k, v| "#{esc(k)}=\"#{esc(v)}\"" }.join(", ")
  end

  def signature(method, url, params)
    base = [
      method.upcase,
      esc(url.split("?").first),
      esc(params.sort.map { |k, v| "#{esc(k)}=#{esc(v)}" }.join("&"))
    ].join("&")

    key = "#{esc(ENV.fetch('X_API_SECRET'))}&#{esc(ENV.fetch('X_ACCESS_SECRET'))}"
    Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", key, base))
  end

  # RFC 3986, which is stricter than CGI.escape: a space must be %20 and the
  # unreserved set must stay literal, or every signature is wrong.
  def esc(value)
    URI.encode_www_form_component(value.to_s).gsub("+", "%20").gsub("%7E", "~")
  end
end
