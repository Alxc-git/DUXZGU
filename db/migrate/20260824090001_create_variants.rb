class CreateVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.string :color
      t.string :color_hex
      t.integer :price_cents
      t.integer :compare_at_price_cents
      t.integer :supplier_cost_cents
      t.string :supplier_variant_id
      t.string :supplier_sku
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :variants, [ :product_id, :position ]
    add_index :variants, [ :product_id, :active ]
    add_index :variants, [ :product_id, :supplier_variant_id ], unique: true, where: "supplier_variant_id IS NOT NULL"
  end
end
