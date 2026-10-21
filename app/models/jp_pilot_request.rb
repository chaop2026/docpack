# A pilot sign-up from the Japanese landing pages (public/safe/jp/*).
#
# This is the ONLY table in the SafeFile JP work that holds personal data, and
# it holds the minimum the offer needs: who to reply to, and enough context to
# prepare a recipient preset. The landing copy promises
# 「ご連絡のためにのみ使用します」, so nothing here may grow into analytics —
# anonymous measurement lives in SafeEvent, which shares no column with this.
class JpPilotRequest < ApplicationRecord
  INDUSTRIES = %w[construction ebid_agent gyoseishoshi other].freeze
  # Buckets, not a number: the form asks for a range so the answer is cheap to
  # give and useless for re-identification.
  MONTHLY_COUNTS = %w[1-2 3-5 6-10 11+].freeze
  FROMS = %w[nyusatsu honnin aimae direct].freeze

  # Deliberately permissive on the local part and strict on the shape. A tighter
  # pattern rejects real addresses; the only thing this needs to establish is
  # that there is something to reply to.
  EMAIL_RE = /\A[^@\s]+@[^@\s.]+(\.[^@\s.]+)+\z/

  validates :company,       presence: true, length: { maximum: 120 }
  validates :industry,      inclusion: { in: INDUSTRIES }
  validates :monthly_count, inclusion: { in: MONTHLY_COUNTS }
  validates :authority,     length: { maximum: 200 }, allow_blank: true
  validates :email,         presence: true, length: { maximum: 200 }, format: { with: EMAIL_RE }
  validates :from,          inclusion: { in: FROMS }

  scope :recent, -> { order(created_at: :desc) }
end
