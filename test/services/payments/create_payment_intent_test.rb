require "test_helper"

module Payments
  class CreatePaymentIntentTest < ActiveSupport::TestCase
    setup do
      @store = stores(:demo)
      @old_api_key = Stripe.api_key
      Stripe.api_key = "sk_test"
      ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test"

      cart = Cart.new(store: @store, session: {})
      cart.add(variants(:black), quantity: 2)
      cart.add(variants(:blue))
      @orders = Orders::PlaceFromCart.call(store: @store, cart:, details: details)
    end

    teardown do
      Stripe.api_key = @old_api_key
      ENV.delete("STRIPE_PUBLISHABLE_KEY")
    end

    test "charges the sum of every order once" do
      params = capture_intent_params

      assert_equal @orders.sum(&:total_cents), params[:amount]
      assert_equal "cad", params[:currency]
    end

    test "charges a repriced single watch at 79.99 dollars" do
      variant = variants(:black)
      variant.update!(price_cents: 7_999)

      cart = Cart.new(store: @store, session: {})
      cart.add(variant)
      orders = Orders::PlaceFromCart.call(store: @store, cart:, details: details)
      captured = nil
      double = intent_double

      with_intent_stub(->(params, _opts) { captured = params; double }) do
        Payments::CreatePaymentIntent.call(store: @store, orders:, details: details)
      end

      assert_equal 7_999, orders.sum(&:total_cents)
      assert_equal 7_999, captured[:amount]
    end

    test "turns on cards and wallets through automatic payment methods" do
      assert_equal({ enabled: true }, capture_intent_params[:automatic_payment_methods])
    end

    test "passes the shipping address so Stripe can run its checks" do
      shipping = capture_intent_params[:shipping]

      assert_equal "Alexis Giard", shipping[:name]
      assert_equal "123 rue Sainte-Catherine", shipping[:address][:line1]
      assert_equal "CA", shipping[:address][:country]
    end

    test "carries every order id so the webhook can mark them all paid" do
      metadata = capture_intent_params[:metadata]

      assert_equal @orders.map(&:id).join(","), metadata[:order_ids]
      assert_equal @orders.first.metadata["checkout_reference"], metadata[:checkout_reference]
    end

    test "records the intent on each order and moves them to checkout_created" do
      with_intent_stub { Payments::CreatePaymentIntent.call(**args) }

      @orders.each do |order|
        order.reload
        assert_equal "pi_test", order.stripe_payment_intent_id
        assert_predicate order, :checkout_created?
      end
    end

    test "refuses to run without keys" do
      ENV.delete("STRIPE_PUBLISHABLE_KEY")

      assert_raises(Payments::CreatePaymentIntent::Error) do
        Payments::CreatePaymentIntent.call(**args)
      end
    end

    test "turns a Stripe failure into a readable message" do
      original = Stripe::PaymentIntent.method(:create)
      Stripe::PaymentIntent.define_singleton_method(:create) { |*| raise Stripe::StripeError, "carte refusee" }

      error = assert_raises(Payments::CreatePaymentIntent::Error) { Payments::CreatePaymentIntent.call(**args) }
      assert_match "carte refusee", error.message
    ensure
      Stripe::PaymentIntent.define_singleton_method(:create, original)
    end

    private

    def args
      { store: @store, orders: @orders, details: details }
    end

    def details
      CheckoutForm.new(
        email: "alexis@exemple.ca",
        first_name: "Alexis",
        last_name: "Giard",
        phone: "+1 514 555 0123",
        address_line1: "123 rue Sainte-Catherine",
        city: "Montreal",
        province: "QC",
        postal_code: "H2X 1Y6",
        country: "CA"
      )
    end

    def capture_intent_params
      captured = nil
      double = intent_double
      with_intent_stub(->(params, _opts) { captured = params; double }) do
        Payments::CreatePaymentIntent.call(**args)
      end
      captured
    end

    def intent_double
      OpenStruct.new(id: "pi_test", client_secret: "pi_test_secret", status: "requires_payment_method")
    end

    # `define_singleton_method` rebinds self to Stripe::PaymentIntent, so the stub
    # can only reach the double through a captured local, never a test method.
    def with_intent_stub(callable = nil)
      double = intent_double
      callable ||= ->(_params, _opts) { double }
      original = Stripe::PaymentIntent.method(:create)
      Stripe::PaymentIntent.define_singleton_method(:create, &callable)
      yield
    ensure
      Stripe::PaymentIntent.define_singleton_method(:create, original)
    end
  end
end
