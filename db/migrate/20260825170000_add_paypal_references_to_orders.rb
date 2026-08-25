class AddPaypalReferencesToOrders < ActiveRecord::Migration[8.1]
  def change
    # The PayPal order is what the customer approves; the capture is what moved
    # the money and what a refund has to be issued against. Both are kept.
    add_column :orders, :paypal_order_id, :string
    add_column :orders, :paypal_capture_id, :string

    add_index :orders, :paypal_order_id
  end
end
