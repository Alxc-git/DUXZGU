class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :store, null: false, foreign_key: true

      # Rotating per-session token. No IP address and no third-party cookie is
      # stored, so the analytics need no consent banner.
      t.string :visitor_token, null: false
      t.string :path, null: false
      t.string :referrer_host
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :device, null: false, default: "desktop"
      # First page view of a session, which is what "visits" counts.
      t.boolean :landing, null: false, default: false

      t.datetime :created_at, null: false
    end

    add_index :visits, [ :store_id, :created_at ]
    add_index :visits, [ :store_id, :visitor_token ]
    add_index :visits, [ :store_id, :landing, :created_at ]
  end
end
