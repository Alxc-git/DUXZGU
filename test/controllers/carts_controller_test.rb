require "test_helper"

class CartsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "rejects product from another store" do
    post cart_lines_path, params: { product_id: products(:other_product).id, quantity: 1 }

    assert_redirected_to root_path
    assert_equal "Ce format n'est plus disponible", flash[:alert]
  end

  test "rejects a variant that belongs to another product" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:other_variant).id,
      quantity: 1
    }

    assert_redirected_to root_path
    assert_equal "Ce format n'est plus disponible", flash[:alert]
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

  test "adds an option and shows it on the cart page" do
    add_black(quantity: 2)

    assert_redirected_to cart_path
    follow_redirect!
    assert_response :success
    assert_select "h1", text: I18n.t("store.cart.title")
    assert_select ".checkout__item", text: /300 g/
    assert_select "input[name=?][value=?]", "quantity", "2"
    assert_select ".cart-layout" do
      assert_select "main.cart-layout__main", count: 1
      assert_select "aside.cart-layout__aside", count: 1
      assert_select ".reassurance-card--trust", count: 1
      assert_select ".reassurance-card--support", count: 1
    end
  end

  test "the cart keeps the selected flavour image and suggests another flavour" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 1,
      flavor: "blueberry"
    }

    follow_redirect!
    assert_response :success
    assert_select "img[src*='duwzgu-checkout-blueberry']", minimum: 1
    assert_select ".checkout__item", text: /#{Flavor.find("blueberry").name}/
    assert_select ".cross-sell", text: /#{I18n.t("store.cart.cross_sell_flavor")}/
    assert_select ".cross-sell input[name='flavor'][value='strawberry']"
  end

  test "two flavours of one size remain separate cart lines" do
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 1,
      flavor: "blueberry"
    }
    post cart_lines_path, params: {
      product_id: products(:demo_product).id,
      variant_id: variants(:black).id,
      quantity: 1,
      flavor: "strawberry"
    }

    follow_redirect!
    assert_select ".checkout__item", text: /#{Flavor.find("blueberry").name}/, minimum: 1
    assert_select ".checkout__item", text: /#{Flavor.find("strawberry").name}/, minimum: 1
    assert_select ".cart-line__controls", count: 2
  end

  test "a missing variant id falls back to the default option" do
    post cart_lines_path, params: { product_id: products(:demo_product).id, quantity: 1 }

    assert_redirected_to cart_path
  end

  test "updating a line changes the quantity" do
    add_black

    patch cart_line_path(variants(:black).id), params: { quantity: 4 }

    assert_redirected_to cart_path
    follow_redirect!
    assert_select "input[name=?][value=?]", "quantity", "4"
  end

  test "removing a line empties the cart" do
    add_black

    delete cart_line_path(variants(:black).id)

    assert_redirected_to cart_path
    follow_redirect!
    assert_select "h2", text: I18n.t("store.cart.empty_title")
  end

  test "an empty cart renders the placeholder without line items" do
    get cart_path

    assert_response :success
    assert_select "h2", text: I18n.t("store.cart.empty_title")
    assert_select ".checkout__item", 0
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
