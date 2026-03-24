class Banner < ApplicationRecord
  POSITIONS = %w[after_result sidebar footer].freeze
  PAGES = %w[compress pdf social all].freeze
  BANNER_TYPES = %w[internal adsense custom].freeze

  validates :title_en, presence: true
  validates :position, inclusion: { in: POSITIONS }
  validates :page, inclusion: { in: PAGES }
  validates :banner_type, inclusion: { in: BANNER_TYPES }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order) }
  scope :for_page, ->(page) { where(page: [page.to_s, "all"]) }
  scope :for_position, ->(position) { where(position: position.to_s) }

  def title
    I18n.locale == :ko && title_ko.present? ? title_ko : title_en
  end

  def description
    I18n.locale == :ko && description_ko.present? ? description_ko : description_en
  end

  def button_text
    I18n.locale == :ko && button_text_ko.present? ? button_text_ko : button_text_en
  end
end
