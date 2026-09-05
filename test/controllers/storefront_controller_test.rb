require "test_helper"

class StorefrontControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "the landing page renders the handoff storefront wired to the product" do
    get root_path

    assert_response :success
    assert_select ".hero__type", text: /#{I18n.t("store.hero.line1")}/
    assert_select ".hero__bleed img[data-flavor-image='hero'][src*='duwzgu-hero-strawberry']"
    assert_select ".hero__bleed source[data-flavor-hero-mobile][srcset*='duwzgu-hero-mobile-strawberry']"
    assert_select "a[href=?]", storefront_product_path(products(:demo_product).slug), text: I18n.t("store.hero.see_product")
    assert_select ".cta-card__media img[data-flavor-image][srcset*='duwzgu-card-fruit-strawberry']"
    assert_select ".editorial-story img[loading='lazy']", count: 2
    schema = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_not schema.key?("aggregateRating"), "Do not publish sample review scores as real ratings"
  end

  test "a linked flavor is used by every purchase form on home and product pages" do
    [ root_path, storefront_product_path(products(:demo_product).slug) ].each do |path|
      get path, params: { flavor: "blueberry" }
      assert_response :success
      assert_select "body[data-flavor-selected-value='blueberry']"
      assert_select "form[data-flavor-purchase]" do |forms|
        assert forms.any?
        forms.each { |form| assert_select form, "input[name='flavor'][value='blueberry']" }
      end
      assert_select "[data-flavor-choice='blueberry'][aria-current='true']"
      assert_select "[data-flavor-image][src*='duwzgu-card-fruit-blueberry']"
    end
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

  test "the product page displays the original price, sale price and discount badge" do
    products(:demo_product).update!(price_cents: 3_499, compare_at_price_cents: 4_999)

    get storefront_product_path(products(:demo_product).slug)

    assert_response :success
    assert_select ".price__was", text: "49,99 $"
    assert_select ".price__now", text: "34,99 $"
    assert_select ".price__sale", text: "-30%"
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
