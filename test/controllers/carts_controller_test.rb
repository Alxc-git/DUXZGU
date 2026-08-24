require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "rejects product from another store" do
    post cart_lines_path, params: { product_id: products(:other_product).id, quantity: 1 }

    assert_redirected_to root_path
    assert_equal "Cette couleur n'est plus disponible", flash[:alert]
  end

  test "rejects a variant that belongs to another product" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:other_variant).id,
      quantity: 1
    }

    assert_redirected_to root_path
    assert_equal "Cette couleur n'est plus disponible", flash[:alert]
  end

  test "buy now sends a valid product to checkout" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 1,
      then: "checkout"
    }

    assert_redirected_to checkout_path
  end

  test "adds a colour and shows it on the cart page" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 2
    }

    assert_redirected_to cart_path
    follow_redirect!
    assert_response :success
    assert_select ".cart-line", 1
    assert_select ".cart-line__colour", text: /Noir/
    assert_select ".site-header__cart-count", text: "2"
  end

  test "a missing variant id falls back to the default colour" do
    post cart_lines_path, params: { product_id: products(:demo_product).id, quantity: 1 }

    assert_redirected_to cart_path
  end

  test "updating a line changes the quantity" do
    add_black

    patch cart_line_path(variants(:black).id), params: { quantity: 4 }

    assert_redirected_to cart_path
    follow_redirect!
    assert_select ".site-header__cart-count", text: "4"
  end

  test "removing a line empties the cart" do
    add_black

    delete cart_line_path(variants(:black).id)

    assert_redirected_to cart_path
    follow_redirect!
    assert_select ".cart__empty", 1
  end

  test "an empty cart offers the product instead of a line list" do
    get cart_path

    assert_response :success
    assert_select ".cart__empty", 1
    assert_select ".cart-line", 0
  end

  test "suggests only the colours that are not already in the cart" do
    add_black

    get cart_path

    assert_response :success
    assert_select ".cart-suggest__item", 1
    assert_select ".cart-suggest__name", text: "Bleu"
  end

  private

  def add_black(quantity: 2)
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity:
    }
  end
end
