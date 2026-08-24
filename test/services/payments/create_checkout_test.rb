require "test_helper"

module Payments
  class CreateCheckoutTest < ActiveSupport::TestCase
    setup do
      @store = stores(:demo)
      @product = products(:demo_product)
      @request = OpenStruct.new(host_with_port: "localhost:3000", protocol: "http://")
      @old_api_key = Stripe.api_key
      Stripe.api_key = "sk_test"
    end

    teardown do
      Stripe.api_key = @old_api_key
    end

    test "creates a pending order and Stripe checkout session" do
      fake_session = OpenStruct.new(id: "cs_test_created", url: "https://checkout.stripe.test/session")
      calls = []

      with_checkout_session_stub(->(params, opts) { calls << [ params, opts ]; fake_session }) do
        result = Payments::CreateCheckout.call(store: @store, product: @product, quantity: 2, request: @request)

        assert_equal fake_session, result.session
        assert_equal "checkout_created", result.order.status
        assert_equal 9_800, result.order.total_cents
        assert_equal @store.id, calls.first.first[:metadata][:store_id]
        assert_equal result.order.id, calls.first.first[:metadata][:order_id]
        assert_equal result.order.id.to_s, calls.first.first[:client_reference_id]
        assert_equal "always", calls.first.first[:customer_creation]
        assert_includes calls.first.first[:success_url], "session_id={CHECKOUT_SESSION_ID}"
      end
    end

    test "collects a shipping address, phone and locale so fulfillment can ship" do
      params = capture_session_params { Payments::CreateCheckout.call(**checkout_args) }

      assert_equal({ allowed_countries: %w[CA] }, params[:shipping_address_collection])
      assert_equal({ enabled: true }, params[:phone_number_collection])
      assert_equal "fr-CA", params[:locale]
    end

    test "honours the shipping countries and locale configured on the store" do
      @store.update!(settings: { "shipping_countries" => %w[ca us], "checkout_locale" => "en" })

      params = capture_session_params { Payments::CreateCheckout.call(**checkout_args) }

      assert_equal({ allowed_countries: %w[CA US] }, params[:shipping_address_collection])
      assert_equal "en", params[:locale]
    end

    test "bills the selected variant price and records it on the order" do
      order = nil
      params = capture_session_params do
        order = Payments::CreateCheckout.call(**checkout_args(variant_id: variants(:blue).id, quantity: 1)).order
      end

      assert_equal variants(:blue), order.variant
      assert_equal 5_400, order.total_cents
      assert_equal 5_400, params[:line_items].first[:price_data][:unit_amount]
      assert_equal "Demo Product - Bleu", params[:line_items].first[:price_data][:product_data][:name]
    end

    test "rejects a variant that does not belong to the product" do
      assert_raises(Payments::CreateCheckout::Error) do
        Payments::CreateCheckout.call(**checkout_args(variant_id: variants(:other_variant).id))
      end
    end

    test "adds a paid shipping line only when the store charges for shipping" do
      params = capture_session_params { Payments::CreateCheckout.call(**checkout_args) }
      assert_nil params[:shipping_options]

      @store.update!(settings: { "shipping_cents" => 999 })
      order = nil
      params = capture_session_params { order = Payments::CreateCheckout.call(**checkout_args).order }

      rate = params[:shipping_options].first[:shipping_rate_data]
      assert_equal 999, rate[:fixed_amount][:amount]
      assert_equal "cad", rate[:fixed_amount][:currency]
      assert_equal 999, order.shipping_cents
      assert_equal 4_900 + 999, order.total_cents
    end

    test "rejects a product from another store" do
      assert_raises(Payments::CreateCheckout::Error) do
        Payments::CreateCheckout.call(store: @store, product: products(:other_product), quantity: 1, request: @request)
      end
    end

    test "explains when Stripe is not configured" do
      Stripe.api_key = nil

      error = assert_raises(Payments::CreateCheckout::Error) do
        Payments::CreateCheckout.call(**checkout_args)
      end

      assert_match "STRIPE_SECRET_KEY", error.message
    end

    private

    def checkout_args(variant_id: variants(:black).id, quantity: 1)
      { store: @store, product: @product, variant_id:, quantity:, request: @request }
    end

    def capture_session_params
      captured = nil
      with_checkout_session_stub(lambda { |params, _opts|
        captured = params
        # Session ids are unique in the orders table, so never reuse one.
        OpenStruct.new(id: "cs_test_#{SecureRandom.hex(4)}", url: "https://checkout.stripe.test/session")
      }) { yield }
      captured
    end

    def with_checkout_session_stub(callable)
      original = Stripe::Checkout::Session.method(:create)
      Stripe::Checkout::Session.define_singleton_method(:create, &callable)
      yield
    ensure
      Stripe::Checkout::Session.define_singleton_method(:create, original)
    end
  end
end
