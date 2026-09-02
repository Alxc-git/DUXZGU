require "test_helper"

class StorefrontControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "the landing page shows the hero and one card per active option" do
    get root_path

    assert_response :success
    assert_select ".hero__title"
    assert_select ".colour-card", 2
    assert_select ".colour-card__name", text: "500 g"
  end

  test "the landing page survives a store with no product" do
    products(:demo_product).update!(active: false)

    get root_path

    assert_response :success
    assert_select ".empty-state"
  end

  test "the product page renders a swatch per option and a gallery rail" do
    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select ".buy-box input[name=variant_id]", 2
    # Options live in the swatches; the rail is the photo strip, so a product with
    # no detail shots attached still carries the product itself as its only slide.
    assert_select ".gallery__thumb", 1
    assert_select "input[name=variant_id][value=?][checked=checked]", variants(:black).id.to_s
    assert_select ".buy-box__price", text: variants(:black).formatted_price
  end

  test "the product gallery uses detail photos from the selected option" do
    variants(:blue).detail_images.attach(
      io: StringIO.new("blue angle"), filename: "01-angle.webp", content_type: "image/webp"
    )
    products(:demo_product).part_images.attach(
      io: StringIO.new("black detail"), filename: "01-detail-noir.png", content_type: "image/png"
    )

    get storefront_product_path(products(:demo_product).slug, option: variants(:blue).id)

    assert_response :success
    assert_select ".gallery__thumb", 2
    assert_select ".gallery__thumb[data-gallery-alt*=?]", "angle", 1
    assert_select ".gallery__thumb[data-gallery-alt*=?]", "detail noir", 0
  end

  test "the product page preselects the option given in the URL" do
    get storefront_product_path(products(:demo_product).slug, option: variants(:blue).id)

    assert_response :success
    assert_select "input[name=variant_id][value=?][checked=checked]", variants(:blue).id.to_s
    assert_select ".buy-box__price", text: variants(:blue).formatted_price
  end

  test "an unknown option in the URL falls back to the default instead of failing" do
    get storefront_product_path(products(:demo_product).slug, option: variants(:other_variant).id)

    assert_response :success
    assert_select "input[name=variant_id][value=?][checked=checked]", variants(:black).id.to_s
  end

  test "hides variants that are not active" do
    variants(:blue).update!(active: false)

    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select ".buy-box input[name=variant_id]", 1
  end

  test "renders a product with no variants at all" do
    products(:demo_product).variants.destroy_all

    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select ".buy-box input[name=variant_id]", 0
    assert_select ".buy-box__price", text: products(:demo_product).formatted_price
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
