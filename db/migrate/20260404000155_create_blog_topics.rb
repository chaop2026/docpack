class CreateBlogTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_topics do |t|
      t.string :topic
      t.string :category
      t.boolean :used, default: false, null: false

      t.timestamps
    end
  end
end
