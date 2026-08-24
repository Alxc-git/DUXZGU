class AddVariantToOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :orders, :variant, null: true, foreign_key: true
  end
end
