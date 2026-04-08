class AddBlogStructureToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :trust_bar, :string
    add_column :posts, :pain_tag, :string
    add_column :posts, :error_mockup, :text
    add_column :posts, :recognition_text, :text
    add_column :posts, :loss_items, :text
    add_column :posts, :stats, :text
    add_column :posts, :subtitle_ko, :string
  end
end
