require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "rejects product from another store" do
    post checkout_path, params: { product_id: products(:other_product).id, quantity: 1 }

    assert_redirected_to root_path
  end

  test "rejects a variant that belongs to another product" do
    with_stripe_key do
      post checkout_path, params: {
        product_id: products(:demo_product).id,
        variant_id: variants(:other_variant).id,
        quantity: 1
      }
    end

    assert_redirected_to root_path
    assert_equal "Veuillez choisir une couleur", flash[:alert]
  end

  private

  def with_stripe_key
    original = Stripe.api_key
    Stripe.api_key = "sk_test"
    yield
  ensure
    Stripe.api_key = original
  end
end
