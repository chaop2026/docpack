class CreateBlogStyles < ActiveRecord::Migration[8.0]
  def change
    create_table :blog_styles do |t|
      t.string :source_name
      t.text :raw_script
      t.text :hooking_patterns
      t.text :sentence_structure
      t.text :psychological_triggers
      t.text :tone_style
      t.boolean :is_active, default: true
      t.text :notes

      t.timestamps
    end
  end
end
