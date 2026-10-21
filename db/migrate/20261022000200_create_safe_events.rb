class CreateSafeEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :safe_events do |t|
      t.string :name, null: false
      # Category-only properties. Every key AND every value is whitelisted in
      # Api::SafeEventsController before it reaches here — no free text, no
      # coordinates, no file names, no IP (not even hashed). The column is jsonb
      # because the key set differs per event, not because it is a free bag.
      t.jsonb  :props, null: false, default: {}

      # created_at only. There is deliberately no updated_at (an event is never
      # updated) and no request fingerprint of any kind.
      t.datetime :created_at, null: false
    end

    add_index :safe_events, [ :created_at, :name ]
  end
end
