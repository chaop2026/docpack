class CreateBanners < ActiveRecord::Migration[8.0]
  def change
    create_table :banners do |t|
      t.string :title_en, null: false, default: ""
      t.string :title_ko, null: false, default: ""
      t.string :description_en, default: ""
      t.string :description_ko, default: ""
      t.string :link_url
      t.string :button_text_en, default: "Learn More"
      t.string :button_text_ko, default: "자세히 보기"
      t.string :image_url
      t.string :position, null: false, default: "after_result"
      t.string :page, null: false, default: "all"
      t.boolean :active, null: false, default: true
      t.integer :sort_order, null: false, default: 0
      t.string :banner_type, null: false, default: "internal"
      t.string :adsense_slot_id

      t.timestamps
    end

    add_index :banners, [:page, :position, :active, :sort_order], name: "index_banners_on_page_position_active_sort"
  end
end
