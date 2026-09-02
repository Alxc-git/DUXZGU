class AllowOnePaymentIntentPerCheckout < ActiveRecord::Migration[8.1]
  # A cart holding several variants becomes one order per variant, all paid by a
  # single PaymentIntent, so the intent id is no longer unique across orders.
  def up
    remove_index :orders, :stripe_payment_intent_id
    add_index :orders, :stripe_payment_intent_id
  end

  def down
    remove_index :orders, :stripe_payment_intent_id
    add_index :orders, :stripe_payment_intent_id, unique: true
  end
end
