require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "redirects an empty cart back to the cart page" do
    get checkout_path

    assert_redirected_to cart_path
    assert_equal "Votre panier est vide", flash[:alert]
  end

  test "renders the checkout form for a filled cart" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 1,
      then: "checkout"
    }

    assert_redirected_to checkout_path
    follow_redirect!
    assert_response :success
    assert_select "form[action=?]", checkout_path
    assert_select ".order-summary", text: /Demo Product/
  end

  test "refuses an incomplete form without creating an order" do
    fill_cart

    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout_form: { email: "" } }
    end

    assert_response :unprocessable_entity
    assert_select ".checkout__errors"
  end

  test "refuses a malformed email" do
    fill_cart

    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout_form: valid_details.merge(email: "pas-un-courriel") }
    end

    assert_response :unprocessable_entity
    assert_select ".checkout__errors", text: /courriel/i
  end

  test "requires a valid shipping phone before payment" do
    fill_cart

    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout_form: valid_details.merge(phone: "") }
    end

    assert_response :unprocessable_entity
    assert_select ".checkout__errors", text: /telephone/i
  end

  test "places the order, empties the cart and confirms" do
    fill_cart

    assert_difference "Order.count", 1 do
      post checkout_path, params: { checkout_form: valid_details }
    end

    assert_redirected_to payment_path
    follow_redirect!
    assert_response :success
    assert_select ".checkout__title", text: "Paiement"
    assert_select ".order-summary__line", 1

    post payment_path
    assert_redirected_to checkout_success_path
    follow_redirect!
    assert_response :success
    assert_select ".confirmation__reference"
    assert_select ".confirmation__line", 1

    get cart_path
    assert_select ".cart__empty", 1
  end

  test "the confirmation only shows orders placed in this session" do
    fill_cart
    post checkout_path, params: { checkout_form: valid_details }

    reset!
    host! "localhost"
    get checkout_success_path

    assert_response :success
    assert_select ".confirmation__card", 0
  end


  # Both leads on this page were written into the template in French, which an
  # English customer read right after paying -- the worst moment to look broken.
  test "the confirmation speaks the visitor's language" do
    fill_cart
    post checkout_path, params: { checkout_form: valid_details }

    get checkout_success_path(locale: "en")

    assert_response :success
    assert_no_match "translation missing", response.body
    assert_no_match "Votre montre est preparee", response.body
    assert_select ".confirmation__lead"
  end
  private

  def fill_cart(quantity: 1)
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity:
    }
  end

  def valid_details
    {
      email: "alexis@exemple.ca",
      first_name: "Alexis",
      last_name: "Giard",
      phone: "+1 514 555 0123",
      address_line1: "123 rue Sainte-Catherine",
      city: "Montreal",
      province: "QC",
      postal_code: "H2X 1Y6",
      country: "CA"
    }
  end
end
