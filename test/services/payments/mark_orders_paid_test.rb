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

    # ---------------------------------------------------------------- Meta

    META_CONFIGURED = {
      "META_PIXEL_ID" => "2010109929639061",
      "META_CONVERSIONS_API_TOKEN" => "SECRET-TOKEN"
    }.freeze

    test "reports one Purchase to Meta for the whole payment" do
      with_env(META_CONFIGURED) do
        assert_enqueued_jobs 1, only: MetaPurchaseJob do
          Payments::MarkOrdersPaid.call(intent_id: "pi_test")
        end
      end
    end

    test "reports nothing more to Meta when the webhook is replayed" do
      with_env(META_CONFIGURED) do
        Payments::MarkOrdersPaid.call(intent_id: "pi_test")

        assert_no_enqueued_jobs only: MetaPurchaseJob do
          Payments::MarkOrdersPaid.call(intent_id: "pi_test")
        end
      end
    end

    test "records the payment and queues fulfillment even when Meta blows up" do
      with_env(META_CONFIGURED) do
        exploding = ->(*) { raise "Meta is down" }

        stubbing(MetaPurchaseJob, :perform_later, exploding) do
          assert_enqueued_jobs @orders.size, only: FulfillOrderJob do
            assert_nothing_raised { Payments::MarkOrdersPaid.call(intent_id: "pi_test") }
          end
        end
      end

      assert @orders.all? { |order| order.reload.paid? }
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
