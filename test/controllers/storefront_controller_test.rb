require "test_helper"

class StorefrontControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "the landing page renders the handoff storefront wired to the product" do
    get root_path

    assert_response :success
    assert_select ".hero__type", text: /Creatine/
    assert_select "a[href=?]", storefront_product_path(products(:demo_product).slug), text: "See the product"
  end

  test "the landing page survives a store with no product" do
    products(:demo_product).update!(active: false)

    get root_path

    assert_response :success
    assert_select "h1", text: "No active product"
  end

  test "the product page exposes the selected purchasable variant" do
    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select "h1", text: products(:demo_product).display_name
    assert_select ".pdp__buy form[action=?]", cart_lines_path, count: 2
    assert_select "input[name='variant_id'][value=?]", variants(:black).id.to_s
  end

  test "inactive variants are not exposed" do
    variants(:blue).update!(active: false)

    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select "input[name='variant_id'][value=?]", variants(:blue).id.to_s, count: 0
  end

  test "renders a product with no variants at all" do
    products(:demo_product).variants.destroy_all

    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select "h1", text: products(:demo_product).display_name
    assert_select "form[action=?]", cart_lines_path, count: 0
  end

  test "an unknown product slug redirects home instead of 500ing" do
    get storefront_product_path("produit-inexistant")

    assert_redirected_to root_path
  end

  test "the product page of another store is not reachable" do
    get storefront_product_path(products(:other_product).slug)

    assert_redirected_to root_path
  end
end
