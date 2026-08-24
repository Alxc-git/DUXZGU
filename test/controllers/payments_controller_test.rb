require "test_helper"

class PaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    @old_api_key = Stripe.api_key
  end

  teardown do
    Stripe.api_key = @old_api_key
    ENV.delete("STRIPE_PUBLISHABLE_KEY")
  end

  test "sends a visitor with no order back to the cart" do
    get payment_path

    assert_redirected_to cart_path
    assert_equal "Votre commande a expire, recommencez votre panier", flash[:alert]
  end

  test "recaps the shipping address taken at the previous step" do
    reach_payment_step

    assert_response :success
    assert_select ".recap", text: /Montreal/
    assert_select ".recap", text: /alexis@exemple\.ca/
    assert_select ".order-summary__line", 1
  end

  test "explains what is missing when Stripe has no keys" do
    Stripe.api_key = nil
    reach_payment_step

    assert_response :success
    assert_select ".payment-notice", text: /STRIPE_SECRET_KEY/
    assert_select ".payment-form", 0
  end

  test "without keys the order can still be recorded, unpaid" do
    Stripe.api_key = nil
    reach_payment_step

    post payment_path

    assert_redirected_to checkout_success_path
    follow_redirect!
    assert_response :success
    assert_select ".confirmation__icon--pending"
    assert_select ".confirmation__reference"
    assert_not Order.last.paid?
  end

  test "the cart is emptied once the order leaves the payment step" do
    Stripe.api_key = nil
    reach_payment_step

    post payment_path
    get cart_path

    assert_select ".cart__empty", 1
  end

  test "mounts the payment element when Stripe is configured" do
    with_stripe_keys do
      with_intent_stub do
        reach_payment_step

        assert_response :success
        assert_select ".payment-form[data-stripe-payment-secret-value=?]", "pi_test_secret"
        assert_select "[data-stripe-payment-key-value=?]", "pk_test"
        assert_select ".payment-notice", 0
      end
    end
  end

  test "a configured store refuses the no-payment shortcut" do
    with_stripe_keys do
      with_intent_stub do
        reach_payment_step

        assert_no_difference "Order.where(status: :paid).count" do
          post payment_path
        end

        assert_redirected_to payment_path
      end
    end
  end

  test "shows the reason when the intent cannot be created" do
    with_stripe_keys do
      original = Stripe::PaymentIntent.method(:create)
      Stripe::PaymentIntent.define_singleton_method(:create) { |*| raise Stripe::StripeError, "compte inactif" }

      reach_payment_step

      assert_response :success
      assert_select ".payment-notice--error", text: /compte inactif/
    ensure
      Stripe::PaymentIntent.define_singleton_method(:create, original)
    end
  end

  private

  def reach_payment_step
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 1
    }
    post checkout_path, params: { checkout_form: details }
    get payment_path
  end

  def details
    {
      email: "alexis@exemple.ca",
      first_name: "Alexis",
      last_name: "Giard",
      address_line1: "123 rue Sainte-Catherine",
      city: "Montreal",
      province: "QC",
      postal_code: "H2X 1Y6",
      country: "CA"
    }
  end

  def with_stripe_keys
    Stripe.api_key = "sk_test"
    ENV["STRIPE_PUBLISHABLE_KEY"] = "pk_test"
    yield
  end

  def with_intent_stub
    double = OpenStruct.new(id: "pi_test", client_secret: "pi_test_secret", status: "requires_payment_method")
    original = Stripe::PaymentIntent.method(:create)
    Stripe::PaymentIntent.define_singleton_method(:create) { |*| double }
    yield
  ensure
    Stripe::PaymentIntent.define_singleton_method(:create, original)
  end
end
