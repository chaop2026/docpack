class Conversion < ApplicationRecord
  has_many_attached :source_files
  has_one_attached :result_file

  validates :conversion_type, inclusion: { in: %w[pdf compress social] }
  validates :status, inclusion: { in: %w[pending done failed] }

  before_validation :set_defaults, on: :create

  scope :expired, -> { where("expires_at < ?", Time.current) }

  private

  def set_defaults
    self.status ||= "pending"
    self.expires_at ||= 1.hour.from_now
  end
end
