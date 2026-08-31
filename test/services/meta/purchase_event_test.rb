require "test_helper"

module Meta
  class PurchaseEventTest < ActiveSupport::TestCase
    setup do
      @order = orders(:paid_order)
      @order.update!(paid_at: Time.current, metadata: { "checkout_reference" => "LX-TEST1234" })
    end

    def consenting_context(extra = {})
      {
        "consent" => PrivacyConsent::ACCEPTED,
        "client_ip_address" => "24.48.0.1",
        "client_user_agent" => "Mozilla/5.0",
        "source_url" => "https://luxtimestyle.com/commande"
      }.merge(extra)
    end

    def with_context(context, order: @order)
      order.update!(metadata: order.metadata.merge("meta" => context))
      order
    end

    test "reports the amount actually paid and the real currency" do
      event = PurchaseEvent.build([ @order ])

      assert_equal "Purchase", event[:event_name]
      assert_in_delta 49.0, event[:custom_data][:value], 0.001
      assert_equal "CAD", event[:custom_data][:currency]
      assert_equal 1, event[:custom_data][:num_items]
    end

    test "sums every order of one payment into a single value" do
      second = @order.dup
      # The checkout session id is unique per row; the intent is what ties the two
      # lines to one payment.
      second.stripe_checkout_session_id = nil
      second.update!(total_cents: 5400, quantity: 2, stripe_payment_intent_id: @order.stripe_payment_intent_id)

      event = PurchaseEvent.build([ @order, second ])

      assert_in_delta 103.0, event[:custom_data][:value], 0.001
      assert_equal 3, event[:custom_data][:num_items]
    end

    test "derives a stable event id from the Stripe payment intent" do
      assert_equal "purchase_stripe_pi_paid", PurchaseEvent.build([ @order ])[:event_id]
      assert_equal PurchaseEvent.build([ @order ])[:event_id], PurchaseEvent.build([ @order ])[:event_id]
    end

    test "derives the event id from the PayPal capture when there is no intent" do
      @order.update!(stripe_payment_intent_id: nil, paypal_capture_id: "8XY12345")

      assert_equal "purchase_paypal_8XY12345", PurchaseEvent.build([ @order ])[:event_id]
    end

    test "falls back to the checkout reference when neither processor left an id" do
      @order.update!(stripe_payment_intent_id: nil)

      assert_equal "purchase_ref_LX-TEST1234", PurchaseEvent.build([ @order ])[:event_id]
    end

    test "hashes the email with SHA-256 after normalising it" do
      with_context(consenting_context)
      @order.update!(email: "  Customer@Example.COM ")

      digest = Digest::SHA256.hexdigest("customer@example.com")

      assert_equal [ digest ], PurchaseEvent.build([ @order ])[:user_data][:em]
    end

    test "hashes the phone digits with the North American country code" do
      with_context(consenting_context)
      @order.update!(phone: "(514) 555-0142", country: "CA")

      digest = Digest::SHA256.hexdigest("15145550142")

      assert_equal [ digest ], PurchaseEvent.build([ @order ])[:user_data][:ph]
    end

    test "passes the pixel cookies through unhashed and keeps the request signals" do
      with_context(consenting_context("fbp" => "fb.1.1700000000.123", "fbc" => "fb.1.1700000000.abc"))

      user_data = PurchaseEvent.build([ @order ])[:user_data]

      assert_equal "fb.1.1700000000.123", user_data[:fbp]
      assert_equal "fb.1.1700000000.abc", user_data[:fbc]
      assert_equal "24.48.0.1", user_data[:client_ip_address]
      assert_equal "Mozilla/5.0", user_data[:client_user_agent]
    end

    test "sends no customer identifier when analytics were declined" do
      with_context(consenting_context("consent" => PrivacyConsent::DECLINED, "fbp" => "fb.1.1.1"))

      user_data = PurchaseEvent.build([ @order ])[:user_data]

      assert_nil user_data[:em]
      assert_nil user_data[:ph]
      assert_nil user_data[:fbp]
      assert_equal "24.48.0.1", user_data[:client_ip_address]
    end

    test "invents nothing when the order carries no browser context" do
      user_data = PurchaseEvent.build([ @order ])[:user_data]

      assert_empty user_data
    end

    test "uses the checkout url the customer was on, then the store domain" do
      with_context(consenting_context)
      assert_equal "https://luxtimestyle.com/commande", PurchaseEvent.build([ @order ])[:event_source_url]

      with_context(consenting_context.except("source_url"))
      assert_equal "https://localhost/", PurchaseEvent.build([ @order ])[:event_source_url]
    end
  end
end
