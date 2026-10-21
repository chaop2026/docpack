class CreateJpPilotRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :jp_pilot_requests do |t|
      t.string :company,        null: false
      t.string :industry,       null: false
      t.string :monthly_count,  null: false
      t.string :authority
      t.string :email,          null: false
      # Which landing page the form was submitted from (nyusatsu|honnin|aimae|direct).
      # Not personal data — one of four fixed strings, validated in the model.
      t.string :from,           null: false, default: "direct"

      t.timestamps
    end

    add_index :jp_pilot_requests, :created_at
  end
end
