# Anonymous, category-only usage counters for SafeFile.
#
# The whole point of this table is what it CANNOT hold. /safe/ promises that
# files never leave the browser and that the processing screen carries no
# third-party script; a measurement endpoint is the one place where that promise
# could quietly be broken, so the shape of a storable event is fixed here and
# nothing else decides it:
#
#   * `name` must be one of NAMES.
#   * every key in `props` must be allowed FOR THAT EVENT (KEYS).
#   * every value must be one of a short, fixed list (VALUES).
#
# There is no free-text key, no coordinate, no file name, no page content, no
# user agent, and no IP — not even hashed. A hash of an IP is still a stable
# per-visitor identifier, which is exactly what this must not have, so the
# controller never computes one.
#
# This class is the single source of truth: the controller validates through
# `SafeEvent.sanitize`, the rake aggregator reads KEYS/VALUES to decide what it
# may group by, and the tests assert against the same constants. Keeping a
# second copy of the list anywhere else is how the two drift apart.
class SafeEvent < ApplicationRecord
  # The table has created_at but no updated_at (an event is never updated);
  # Rails only writes timestamp columns that exist, so nothing to configure.

  NAMES = %w[upload doc_class purpose download landing_view cta_click].freeze

  VALUES = {
    "doc_class" => %w[shikaku_kakuninsho unten_menkyo mynumber_card juminhyo unclassified none],
    "purpose"   => %w[identity_submit my_number_procedure bid_attachment consult_share],
    "format"    => %w[jpg png pdf],
    "locale"    => %w[ko en ja es],
    "from"      => %w[nyusatsu honnin aimae direct],
    "ext"       => %w[pdf jpg png docx other],
    "pages"     => %w[1 2 3-5 6+],
    # Only on `purpose`. A landing page may arrive with ?purpose=…, which the
    # tool applies during init — so one `purpose` event is written before the
    # visitor has touched anything. Without this key that row is identical to
    # "the visitor changed the dropdown", and every purpose statistic silently
    # counts preselections as choices. Two fixed categories, no free text.
    "source"    => %w[init user],
    # Which channel sent this visit, read from ?utm_source= and mapped onto this
    # fixed list (anything else becomes "other"; absent becomes "none").
    #
    # Added 2026-10-25 because P16 — "share of landing visits arriving from
    # social" — had no dimension to compute from. `from` records WHICH landing
    # page, not where the visitor came from, so the metric was unmeasurable and
    # would have reported a confident 0. `blog` is listed and is deliberately
    # excluded from P16's numerator (JpWeeklyKpi): the blog's own in-article CTA
    # is internal linking, and counting it would make the metric rise as the
    # blog grows, which is the opposite of what P16 asks.
    "utm_source" => %w[x linkedin youtube blog direct other none],

    # ── S10: the same question, asked with a parameter that survives ────────
    #
    # `via` replaces `utm_source` in every link we publish from now on, because
    # `?utm_*` is blocked by ad/tracker-blocking browser extensions BEFORE the
    # request is made. The server was answering 200 the whole time; the author's
    # own Chrome would not open his own shared link. A measurement whose
    # parameter is stripped on the way in measures nothing.
    #
    # `utm_source` above is KEPT, not replaced. Rows already exist with it, and
    # links already published — blog bodies, tweets posted before 2026-10-27 —
    # keep arriving with it for as long as anyone clicks them. Deleting the key
    # would push those visits into `none`, which reads as "traffic fell" when
    # what actually happened is "we stopped counting". JpWeeklyKpi sums the two.
    #
    # ── `email` (S11) ──────────────────────────────────────────────────────
    #
    # Outreach mail is the only channel with real volume right now — eight
    # firms were contacted on 2026-11-01 and the second round is planned
    # (docs/jp/jp_outreach_playbook_2026-11-01.md §6), and every one of those
    # visits was landing as "no source recorded". The playbook asked for the
    # value in §5-3.
    #
    # It is deliberately NOT added to `utm_source` above. That list describes
    # links already published and must not grow: jp.js accepts a value only if
    # the server's list has it, so a `?utm_source=email` that the client sent
    # and the server refused would discard the WHOLE event (sanitize returns
    # nil) — and sendBeacon never reads the response, so the loss would be
    # invisible from both ends. Two lists, two purposes.
    #
    # `email` is in P16's DENOMINATOR only, like `blog`: P16 asks for the share
    # of landing visits arriving from SOCIAL, and a mail sent by hand to a
    # named firm is not that. Counting it would make P16 rise as outreach
    # scaled, which is the opposite of what the metric is for (JpWeeklyKpi).
    "via"        => %w[x linkedin youtube blog email direct other none],

    # Which episode's link was clicked. New information: `utm_campaign=epNN`
    # was in the URL but was never stored (it is not in KEYS below), so
    # per-episode attribution has never been measurable.
    #
    # A fixed list, like everything else here — the premise of this table is
    # that only category values are stored, and `ep` arrives in a URL a visitor
    # can edit. 33 is the planned run (content/jp/topics.json); anything else
    # becomes "other".
    "ep"         => (1..33).map { |n| format("ep%02d", n) }.push("other").freeze
  }.freeze

  # Which keys each event may carry. A key that is valid for one event is not
  # automatically valid for another — `format` only means something on a
  # download, and a landing page has no document to classify.
  KEYS = {
    "upload"       => %w[ext pages locale from],
    "doc_class"    => %w[doc_class locale from],
    "purpose"      => %w[purpose doc_class locale from source],
    "download"     => %w[format doc_class purpose locale from],
    # `utm_source` and `via` are both listed on purpose — see VALUES. A visit
    # arriving on an old link carries the first, a new link carries the second,
    # and an event never carries both (jp.js sends whichever it found).
    "landing_view" => %w[from locale utm_source via ep],
    "cta_click"    => %w[from purpose locale utm_source via ep]
  }.freeze

  validates :name, inclusion: { in: NAMES }
  validate  :props_whitelisted

  scope :since, ->(time) { where(created_at: time..) }

  # Keys that describe the SAME fact and must never arrive together (S10b).
  #
  # `via` and `utm_source` both answer "which channel sent this visit" — the
  # first on links published from 2026-11-01, the second on everything already
  # out there. KEYS allows both because a visit may arrive on either, but one
  # visit has exactly one source, and JpWeeklyKpi#attributed_landing_views ADDS
  # the two groupings together. An event carrying both would therefore be
  # counted twice, in the one metric (P16) whose whole job is a ratio.
  #
  # jp.js does not send both — it sends whichever it found. That is a property
  # of today's client, not a property of the endpoint, and this endpoint is
  # reachable by anything that can POST JSON. Cross-review Q1 is exactly right
  # that "the client does not do it" is not an answer.
  MUTUALLY_EXCLUSIVE_KEYS = [ %w[via utm_source] ].freeze

  # Returns the props hash reduced to whitelisted (key, value) pairs, or nil if
  # the event name is unknown, ANY key/value is not allowed, or two keys that
  # describe one fact arrive together.
  #
  # Rejecting the whole event rather than dropping the offending pair is
  # deliberate. A partially-stored event is a row that looks like data but
  # describes something that did not happen, and `beacon` responses are never
  # read by the browser, so a silent drop would be invisible from both ends. A
  # rejection is at least a 422 in the logs and a red test.
  #
  # The same reasoning decides the mutual-exclusion case: dropping one of the
  # two and keeping the other would be GUESSING which channel the visit came
  # from, and the guess would be stored as though it had been measured.
  def self.sanitize(name, props)
    allowed = KEYS[name.to_s]
    return nil unless allowed

    out = {}
    (props || {}).each do |k, v|
      key = k.to_s
      return nil unless allowed.include?(key)

      value = v.to_s
      return nil unless VALUES.fetch(key, []).include?(value)

      out[key] = value
    end

    MUTUALLY_EXCLUSIVE_KEYS.each do |group|
      return nil if (out.keys & group).length > 1
    end

    out
  end

  private

  def props_whitelisted
    unless props.is_a?(Hash)
      errors.add(:props, "must be a hash")
      return
    end

    errors.add(:props, "contains a key or value that is not whitelisted") if self.class.sanitize(name, props).nil?
  end
end
