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
    "pages"     => %w[1 2 3-5 6+]
  }.freeze

  # Which keys each event may carry. A key that is valid for one event is not
  # automatically valid for another — `format` only means something on a
  # download, and a landing page has no document to classify.
  KEYS = {
    "upload"       => %w[ext pages locale from],
    "doc_class"    => %w[doc_class locale from],
    "purpose"      => %w[purpose doc_class locale from],
    "download"     => %w[format doc_class purpose locale from],
    "landing_view" => %w[from locale],
    "cta_click"    => %w[from purpose locale]
  }.freeze

  validates :name, inclusion: { in: NAMES }
  validate  :props_whitelisted

  scope :since, ->(time) { where(created_at: time..) }

  # Returns the props hash reduced to whitelisted (key, value) pairs, or nil if
  # the event name is unknown or ANY key/value is not allowed.
  #
  # Rejecting the whole event rather than dropping the offending pair is
  # deliberate. A partially-stored event is a row that looks like data but
  # describes something that did not happen, and `beacon` responses are never
  # read by the browser, so a silent drop would be invisible from both ends. A
  # rejection is at least a 422 in the logs and a red test.
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
