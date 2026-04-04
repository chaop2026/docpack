class BlogTopic < ApplicationRecord
  validates :topic, presence: true
  validates :category, inclusion: { in: %w[pdf image office student freelancer global] }

  scope :unused, -> { where(used: false) }
end
