require "test_helper"

class StorefrontControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "renders the product page with a swatch per active colour" do
    get root_path

    assert_response :success
    assert_select "input[name=variant_id]", 2
    assert_select "input[name=variant_id][value=?][checked=checked]", variants(:black).id.to_s
    assert_select ".variant-swatch__name", text: "Bleu"
  end

  test "hides variants that are not active" do
    variants(:blue).update!(active: false)

    get root_path

    assert_response :success
    assert_select "input[name=variant_id]", 1
  end

  test "renders without a picker when the product has no variants" do
    products(:demo_product).variants.destroy_all

    get root_path

    assert_response :success
    assert_select "input[name=variant_id]", 0
    assert_select ".product-hero__price"
  end
end
