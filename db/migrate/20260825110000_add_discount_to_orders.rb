class AddDiscountToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :discount_cents, :integer, null: false, default: 0
  end
end
