class CreateConversions < ActiveRecord::Migration[8.0]
  def change
    create_table :conversions do |t|
      t.string :conversion_type
      t.string :status
      t.integer :original_size
      t.integer :result_size
      t.datetime :expires_at

      t.timestamps
    end
  end
end
