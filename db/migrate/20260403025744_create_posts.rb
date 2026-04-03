class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :title_ko
      t.string :title_en
      t.text :body_ko
      t.text :body_en
      t.string :slug
      t.string :category
      t.string :status
      t.datetime :published_at
      t.text :cover_svg
      t.string :meta_description_ko
      t.string :meta_description_en
      t.integer :view_count, default: 0

      t.timestamps
    end
    add_index :posts, :slug, unique: true
  end
end
