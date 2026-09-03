require "test_helper"

class CheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "redirects an empty cart back to the cart page" do
    get checkout_path

    assert_redirected_to cart_path
    assert_equal "Votre panier est vide", flash[:alert]
  end

  test "renders the checkout form for a filled cart" do
    fill_cart

    get checkout_path

    assert_response :success
    assert_select "h1", text: "Checkout"
    assert_select "form[action=?]", checkout_path
    assert_select "input#checkout_form_email"
  end

  test "freezes the Meta browser context onto the orders it places" do
    fill_cart
    post checkout_path, params: { checkout_form: valid_details }

    context = Order.order(:id).last.metadata["meta"]

    assert_equal "127.0.0.1", context["client_ip_address"]
    assert_equal checkout_url, context["source_url"]
    assert_not context.key?("fbp"), "no pixel cookie was set, so none must be invented"
  end

  test "wires the address fields to the autocomplete controller" do
    fill_cart
    get checkout_path

    assert_response :success
    assert_select "form[data-controller='address-autocomplete']"
    assert_select "input[role='combobox'][data-address-autocomplete-target~='query']", count: 2
    assert_select "input[data-autocomplete-kind='address']"
    assert_select "input[data-autocomplete-kind='postal']"
    assert_select "ul#address-suggestions[role='listbox']"
    assert_select "ul#postal-suggestions[role='listbox']"
    assert_includes response.body, "controllers/address_autocomplete_controller"
  end

  test "refuses an incomplete form without creating an order" do
    fill_cart

    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout_form: { email: "" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']"
  end

  test "refuses a malformed email" do
    fill_cart

    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout_form: valid_details.merge(email: "pas-un-courriel") }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /courriel/i
  end

  test "requires a valid shipping phone before payment" do
    fill_cart

    assert_no_difference "Order.count" do
      post checkout_path, params: { checkout_form: valid_details.merge(phone: "") }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /telephone/i
  end

  test "places the order, empties the cart and confirms" do
    fill_cart

    assert_difference "Order.count", 1 do
      post checkout_path, params: { checkout_form: valid_details }
    end

    assert_redirected_to payment_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Payment"

    post payment_path
    assert_redirected_to checkout_success_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Order recorded"
    assert_select ".checkout__line", text: /#{products(:demo_product).display_name}/

    get cart_path
    assert_select "p", text: "Your cart is empty."
  end

  test "the confirmation only shows orders placed in this session" do
    fill_cart
    post checkout_path, params: { checkout_form: valid_details }

    reset!
    host! "localhost"
    get checkout_success_path

    assert_response :success
    assert_select "p", text: "No order is attached to this browser session."
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
