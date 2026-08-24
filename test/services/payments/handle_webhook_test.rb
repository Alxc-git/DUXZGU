require "test_helper"

module Payments
  class HandleWebhookTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    test "marks checkout session completed as paid and enqueues fulfillment once" do
      order = Order.create!(store: stores(:demo), product: products(:demo_product), quantity: 1, currency: "cad").tap do |record|
        record.recalculate_totals!
        record.save!
      end
      session = OpenStruct.new(
        id: "cs_completed_#{order.id}",
        payment_intent: "pi_completed_#{order.id}",
        customer: "cus_completed",
        customer_email: "buyer@example.com",
        metadata: { "order_id" => order.id.to_s },
        customer_details: {
          "email" => "buyer@example.com",
          "name" => "Grace Hopper",
          "phone" => "555",
          "address" => {
            "line1" => "1 Main St",
            "city" => "Paris",
            "postal_code" => "75001",
            "country" => "FR"
          }
        }
      )
      event = OpenStruct.new(type: "checkout.session.completed", data: OpenStruct.new(object: session))

      assert_enqueued_jobs 1, only: FulfillOrderJob do
        Payments::HandleWebhook.call(event:)
        Payments::HandleWebhook.call(event:)
      end

      order.reload
      assert_predicate order, :paid?
      assert_equal "pi_completed_#{order.id}", order.stripe_payment_intent_id
      assert_equal "buyer@example.com", order.email
    end

    test "reads the shipping address from collected_information" do
      order = build_order
      session = checkout_session(order).tap do |object|
        object.collected_information = {
          "shipping_details" => {
            "name" => "Grace Hopper",
            "address" => {
              "line1" => "1250 rue Sainte-Catherine O",
              "line2" => "App 302",
              "city" => "Montreal",
              "state" => "QC",
              "postal_code" => "H3G 1P1",
              "country" => "CA"
            }
          }
        }
      end
      event = OpenStruct.new(type: "checkout.session.completed", data: OpenStruct.new(object: session))

      Payments::HandleWebhook.call(event:)

      order.reload
      assert_equal "1250 rue Sainte-Catherine O", order.address_line1
      assert_equal "App 302", order.address_line2
      assert_equal "Montreal", order.city
      assert_equal "QC", order.province
      assert_equal "H3G 1P1", order.postal_code
      assert_equal "CA", order.country
      assert_equal "Grace", order.first_name
      assert_equal "Hopper", order.last_name
    end

    test "falls back to the billing address on older webhook payloads" do
      order = build_order
      event = OpenStruct.new(type: "checkout.session.completed", data: OpenStruct.new(object: checkout_session(order)))

      Payments::HandleWebhook.call(event:)

      assert_equal "1 Main St", order.reload.address_line1
      assert_equal "CA", order.country
    end

    test "records the amounts Stripe actually charged" do
      order = build_order
      session = checkout_session(order).tap do |object|
        object.amount_subtotal = 3_999
        object.amount_total = 4_998
        object.currency = "cad"
        object.total_details = { "amount_tax" => 0 }
        object.shipping_cost = { "amount_total" => 999 }
      end
      event = OpenStruct.new(type: "checkout.session.completed", data: OpenStruct.new(object: session))

      Payments::HandleWebhook.call(event:)

      order.reload
      assert_equal 3_999, order.subtotal_cents
      assert_equal 999, order.shipping_cents
      assert_equal 4_998, order.total_cents
    end

    test "payment failure marks order failed" do
      order = orders(:paid_order)
      intent = OpenStruct.new(id: "pi_failed", metadata: { "order_id" => order.id.to_s })
      event = OpenStruct.new(type: "payment_intent.payment_failed", data: OpenStruct.new(object: intent))

      Payments::HandleWebhook.call(event:)

      assert_predicate order.reload, :failed?
    end

    private

    def build_order
      Order.create!(store: stores(:demo), product: products(:demo_product), quantity: 1, currency: "cad").tap do |record|
        record.recalculate_totals!
        record.save!
      end
    end

    def checkout_session(order)
      OpenStruct.new(
        id: "cs_completed_#{order.id}",
        payment_intent: "pi_completed_#{order.id}",
        customer: "cus_completed",
        customer_email: "buyer@example.com",
        metadata: { "order_id" => order.id.to_s },
        customer_details: {
          "email" => "buyer@example.com",
          "name" => "Grace Hopper",
          "phone" => "555",
          "address" => {
            "line1" => "1 Main St",
            "city" => "Montreal",
            "postal_code" => "H3G 1P1",
            "country" => "CA"
          }
        }
      )
    end
  end
end
