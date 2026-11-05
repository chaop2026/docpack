require "net/http"
require "uri"
require "json"

# IndexNow — tells Bing (and therefore ChatGPT search and Copilot, which read
# Bing's index) that a URL exists, the moment it goes live.
#
# ── Why this exists ─────────────────────────────────────────────────────────
#
# The 2026-11-02 audit measured the problem: every SafeFile JP page sat in
# Search Console as "Discovered – currently not indexed" — Google knew the URLs
# and had not crawled them — and Bing did not know about the site at all. A
# weekly blog post that nothing links to and nobody is told about is discovered
# whenever a crawler gets round to it, which for a new section is weeks.
#
# IndexNow is a single POST. It is not a ranking signal and it is not a promise
# to index; it only removes "nobody told the engine" from the list of reasons
# a page is missing.
#
# ── The key is read from ENV and never written anywhere ─────────────────────
#
# IndexNow authenticates by having the same key served from the site at
# <key>.txt, so the key is PUBLIC by design — but it is not in this repository,
# because this repository is public and a committed key cannot be rotated
# without a commit. ENV["INDEXNOW_KEY"] is the only source:
#
#   * Api::IndexNowKeyController serves /<key>.txt from that same value, so the
#     file Bing fetches and the key we send can never disagree.
#   * `key_location` is sent explicitly, which is what makes a dynamically
#     served key file acceptable to the protocol.
#   * Nothing in here logs the key. `report` prints its presence and length
#     only — the same rule XClient follows for its tokens, for the same reason.
#
# ── Dry run is the default posture ──────────────────────────────────────────
#
# No key → dry run. `INDEXNOW_DRY_RUN=1` → dry run. A dry run logs the exact
# payload it would have sent (minus the key) and returns `:dry_run`, so the
# whole path can be exercised without talking to anyone.
#
# ── Failure must never cost the publish ─────────────────────────────────────
#
# Every entry point rescues StandardError and returns a result. The caller
# (PublishScheduledPostsJob) has already made the post public by the time this
# runs; an unreachable third-party endpoint must not turn a successful publish
# into a failed job, and must not be retried into a loop. The record of what
# happened is the log line and the returned status.
module IndexNow
  ENDPOINT = "https://api.indexnow.org/indexnow".freeze

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  # Bing documents a cap of 10,000 URLs per submission; this app will never
  # approach it, and a bound that exists is better than one that is assumed.
  MAX_URLS = 100

  # The same shape the route constraint accepts — character for character.
  #
  # ── Why this is validated here and not only at the route ───────────────────
  #
  # `config/routes.rb` serves the key file from
  #   get "/:indexnow_key", constraints: { indexnow_key: /[A-Za-z0-9][A-Za-z0-9_-]{7,127}\.txt/ }
  # and until S11c this module only checked that ENV["INDEXNOW_KEY"] was
  # non-blank. A value that is non-blank but outside that shape — a trailing
  # newline from a here-doc, a quoted string, something under 8 characters —
  # produced the worst of the three possible outcomes: submission went ahead
  # and advertised a `keyLocation` that the router would never match, so
  # /<key>.txt answered 404 and Bing rejected the ownership check. Nothing in
  # our logs says "refused"; IndexNow returns 202 ("key not yet validated"),
  # which is also what a perfectly good first submission returns.
  #
  # So a malformed key is now the same posture as no key at all: dry run. That
  # is strictly better than submitting with one, because a dry run is a
  # recorded status the weekly report prints, and a 202 that never validates is
  # indistinguishable from success.
  #
  # IndexNow's own documentation asks for 8–128 characters of [a-zA-Z0-9-]; the
  # route's regex additionally allows `_` and requires the first character to be
  # alphanumeric. Matching the ROUTE rather than the spec is the point: the
  # route is what decides whether the file can be served, and a key the spec
  # likes but our own router cannot serve is exactly the failure above.
  KEY_FORMAT = /\A[A-Za-z0-9][A-Za-z0-9_-]{7,127}\z/

  class << self
    def key
      raw = ENV["INDEXNOW_KEY"].presence
      return nil if raw.nil?
      return raw if KEY_FORMAT.match?(raw)

      warn_malformed_key(raw)
      nil
    end

    def dry_run?
      ENV["INDEXNOW_DRY_RUN"] == "1" || key.nil?
    end

    # Presence and length only — never the value.
    def report
      { "present" => !key.nil?, "length" => key.to_s.length, "dry_run" => dry_run? }
    end

    # The URL Bing fetches to verify ownership. Derived from the key rather
    # than configured separately, so the two cannot drift.
    def key_location(base_url)
      return nil if key.nil?

      "#{base_url.to_s.chomp('/')}/#{key}.txt"
    end

    # urls: absolute URLs on our own host.
    #
    # → { status: :sent | :dry_run | :skipped | :failed, urls:, code:, error: }
    #
    # `:skipped` is for "there was nothing to submit" and for a configuration
    # that cannot submit; `:dry_run` is "configured not to submit". They are
    # different facts and are not folded together, because the weekly report
    # has to be able to say which one it is.
    def submit(urls, base_url: default_base_url, logger: Rails.logger, http: nil)
      list = Array(urls).map(&:to_s).reject(&:blank?).uniq.first(MAX_URLS)
      return { status: :skipped, urls: [], reason: "no urls" } if list.empty?

      payload = {
        "host" => URI.parse(base_url).host,
        "urlList" => list
      }

      if dry_run?
        logger&.info(
          "[IndexNow] DRY RUN — would submit #{list.size} url(s): #{list.join(', ')} " \
          "(key #{report['present'] ? "present, #{report['length']} chars" : 'absent'})"
        )
        return { status: :dry_run, urls: list }
      end

      payload["key"] = key
      payload["keyLocation"] = key_location(base_url)

      code = (http || method(:post_json)).call(ENDPOINT, payload)

      # 200 and 202 both mean accepted; 202 additionally means "key not yet
      # validated", which is normal on the first submission after a deploy.
      if [ 200, 202 ].include?(code)
        logger&.info("[IndexNow] submitted #{list.size} url(s), HTTP #{code}: #{list.join(', ')}")
        { status: :sent, urls: list, code: code }
      else
        # Deliberately not raised. See the header: the post is already public.
        logger&.error("[IndexNow] refused with HTTP #{code} for #{list.size} url(s): #{list.join(', ')}")
        { status: :failed, urls: list, code: code }
      end
    rescue StandardError => e
      logger&.error("[IndexNow] could not submit #{list&.size || 0} url(s) — #{e.class}: #{e.message}")
      { status: :failed, urls: list || [], error: "#{e.class}: #{e.message}" }
    end

    # Same default as ApplicationHelper#base_url. Public because a job has no
    # view helpers and must not grow a second idea of what this site is called.
    def default_base_url
      ENV.fetch("BASE_URL", "https://slimfile.net")
    end

    private

    # One line, and the VALUE IS NOT IN IT — length only, the same rule `report`
    # follows and XClient follows for its tokens. The key is public by protocol,
    # but a rejected key is usually a configuration mistake (a stray quote, a
    # newline, a paste of the wrong secret) and a log line is the wrong place to
    # find out which secret somebody pasted.
    #
    # Warned once per distinct rejected value rather than on every call: `key`
    # is consulted five times in one `submit` (dry_run? once, report twice with
    # two calls each), and five identical lines read as five problems. Keyed on
    # the value so a corrected-then-broken-again env var warns again.
    def warn_malformed_key(raw)
      return if @warned_key_value == raw

      @warned_key_value = raw
      Rails.logger&.warn(
        "[IndexNow] INDEXNOW_KEY is set but does not match the shape the key-file route " \
        "can serve (#{raw.length} chars; needs 8-128 of [A-Za-z0-9_-] starting alphanumeric). " \
        "Falling back to DRY RUN — submitting with it would advertise a keyLocation that " \
        "answers 404."
      )
    end

    # → HTTP status code. Separated out so `submit` can be driven by a stub in
    # tests without stubbing Net::HTTP itself.
    def post_json(url, payload)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      req = Net::HTTP::Post.new(uri.request_uri, "content-type" => "application/json; charset=utf-8")
      req.body = payload.to_json
      http.request(req).code.to_i
    end
  end
end
