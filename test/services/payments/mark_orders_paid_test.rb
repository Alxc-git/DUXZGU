require "test_helper"

module Payments
  class MarkOrdersPaidTest < ActiveJob::TestCase
    setup do
      cart = Cart.new(store: stores(:demo), session: {})
      cart.add(variants(:black))
      cart.add(variants(:blue))
      @orders = Orders::PlaceFromCart.call(store: stores(:demo), cart:, details: details)
      @orders.each { |order| order.update!(stripe_payment_intent_id: "pi_test") }
    end

    test "marks every order of the checkout paid" do
      Payments::MarkOrdersPaid.call(intent_id: "pi_test", metadata: { "order_ids" => @orders.map(&:id).join(",") })

      @orders.each do |order|
        order.reload
        assert_predicate order, :paid?
        assert_not_nil order.paid_at
      end
    end

    test "falls back to the intent id when metadata carries no ids" do
      Payments::MarkOrdersPaid.call(intent_id: "pi_test")

      assert @orders.all? { |order| order.reload.paid? }
    end

    test "queues fulfillment once per order" do
      assert_enqueued_jobs @orders.size, only: FulfillOrderJob do
        Payments::MarkOrdersPaid.call(intent_id: "pi_test")
      end
    end

    test "running twice does not queue fulfillment again" do
      Payments::MarkOrdersPaid.call(intent_id: "pi_test")

      assert_no_enqueued_jobs only: FulfillOrderJob do
        Payments::MarkOrdersPaid.call(intent_id: "pi_test")
      end
    end

    test "leaves an order that already shipped alone" do
      shipped = @orders.first
      shipped.update!(status: :shipped)

      Payments::MarkOrdersPaid.call(intent_id: "pi_test")

      assert_predicate shipped.reload, :shipped?
      assert_predicate @orders.last.reload, :paid?
    end

    private

    def details
      CheckoutForm.new(
        email: "alexis@exemple.ca", first_name: "Alexis", last_name: "Giard",
        phone: "+1 514 555 0123",
        address_line1: "123 rue Sainte-Catherine", city: "Montreal",
        postal_code: "H2X 1Y6", country: "CA"
      )
    end
  end
end
