class CreateStores < ActiveRecord::Migration[8.1]
  def change
    create_table :stores do |t|
      t.string :name, null: false
      t.string :domain, null: false
      t.string :slug, null: false
      t.boolean :active, null: false, default: true
      t.string :currency, null: false, default: "eur"
      t.string :stripe_account_id
      t.string :supplier_type, null: false, default: "cj"
      t.jsonb :supplier_settings, null: false, default: {}
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :stores, :domain, unique: true
    add_index :stores, :slug, unique: true
    add_index :stores, :active
  end
end
