class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :store, null: false, foreign_key: true
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :stripe_customer_id
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :customers, [ :store_id, :email ]
    add_index :customers, :stripe_customer_id
  end
end
