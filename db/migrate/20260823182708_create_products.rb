class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.references :store, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :price_cents, null: false
      t.integer :compare_at_price_cents
      t.string :currency, null: false, default: "eur"
      t.boolean :active, null: false, default: true
      t.string :supplier_product_id
      t.string :supplier_variant_id
      t.string :supplier_sku
      t.integer :supplier_cost_cents
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end

    add_index :products, [ :store_id, :slug ], unique: true
    add_index :products, [ :store_id, :active ]
    add_index :products, :supplier_variant_id
  end
end
