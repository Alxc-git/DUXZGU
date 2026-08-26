class AddDeliveryEstimateToOrders < ActiveRecord::Migration[8.1]
  def change
    # The window CJ quoted for this address, frozen at checkout so the customer
    # is always shown the promise that was made to them, not today's rate.
    add_column :orders, :delivery_min_days, :integer
    add_column :orders, :delivery_max_days, :integer
    add_column :orders, :shipping_carrier, :string
  end
end
