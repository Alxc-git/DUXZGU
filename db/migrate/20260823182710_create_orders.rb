class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :store, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.references :customer, null: true, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :quantity, null: false, default: 1
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :shipping_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.string :currency, null: false, default: "eur"
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :province
      t.string :postal_code
      t.string :country
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.string :stripe_customer_id
      t.string :supplier_order_id
      t.string :supplier_status
      t.string :tracking_number
      t.string :tracking_url
      t.jsonb :metadata, null: false, default: {}
      t.datetime :paid_at
      t.datetime :submitted_to_supplier_at
      t.datetime :shipped_at
      t.datetime :delivered_at
      t.datetime :refunded_at

      t.timestamps
    end

    add_index :orders, [ :store_id, :status ]
    add_index :orders, [ :store_id, :created_at ]
    add_index :orders, :email
    add_index :orders, :stripe_checkout_session_id, unique: true
    add_index :orders, :stripe_payment_intent_id, unique: true
    add_index :orders, :supplier_order_id, unique: true
    add_index :orders, :supplier_status
  end
end
