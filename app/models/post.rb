class Post < ApplicationRecord
  validates :title_ko, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, inclusion: { in: %w[pdf image office student freelancer global] }
  validates :status, inclusion: { in: %w[draft scheduled published] }

  scope :published, -> { where(status: "published") }
  scope :scheduled_ready, -> { where(status: "scheduled").where("published_at <= ?", Time.current) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  before_validation :generate_slug, if: -> { slug.blank? && title_ko.present? }

  def title
    I18n.locale == :ko ? title_ko : (title_en.presence || title_ko)
  end

  def body
    I18n.locale == :ko ? body_ko : (body_en.presence || body_ko)
  end

  def meta_description
    I18n.locale == :ko ? meta_description_ko : (meta_description_en.presence || meta_description_ko)
  end

  def publish!
    update!(status: "published", published_at: Time.current) if published_at.blank?
    update!(status: "published")
  end

  private

  def generate_slug
    base = title_ko.to_s.parameterize
    base = SecureRandom.hex(6) if base.blank?
    self.slug = base
    counter = 1
    while Post.where(slug: slug).where.not(id: id).exists?
      self.slug = "#{base}-#{counter}"
      counter += 1
    end
  end
end
