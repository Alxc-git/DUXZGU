require "test_helper"

class TranslatableNameTest < ActiveSupport::TestCase
  setup do
    @variant = variants(:black)
    @variant.update!(name: "Format 300 g", translations: { "en" => { "name" => "300 g size" } })
  end

  test "shows the stored name in the default language" do
    I18n.with_locale(:fr) { assert_equal "Format 300 g", @variant.display_name }
  end

  test "shows the translation in the other language" do
    I18n.with_locale(:en) { assert_equal "300 g size", @variant.display_name }
  end

  # A shop that has not translated an option yet must still see something.
  test "falls back to the stored name when no translation exists" do
    @variant.update!(translations: {})

    I18n.with_locale(:en) { assert_equal "Format 300 g", @variant.display_name }
  end

  test "an empty translation is treated as missing" do
    @variant.update!(translations: { "en" => { "name" => "" } })

    I18n.with_locale(:en) { assert_equal "Format 300 g", @variant.display_name }
  end

  test "the order line names the product in the reader's language" do
    order = orders(:paid_order)
    order.product.update!(name: "Produit", translations: { "en" => { "name" => "Product" } })
    order.update!(variant: @variant)

    I18n.with_locale(:en) { assert_equal "Product - 300 g size", order.reload.line_item_name }
    I18n.with_locale(:fr) { assert_equal "Produit - Format 300 g", order.reload.line_item_name }
  end
end
