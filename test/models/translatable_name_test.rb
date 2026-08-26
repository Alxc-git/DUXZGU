require "test_helper"

class TranslatableNameTest < ActiveSupport::TestCase
  setup do
    @variant = variants(:black)
    @variant.update!(name: "Noir Integral", translations: { "en" => { "name" => "All Black" } })
  end

  test "shows the stored name in the default language" do
    I18n.with_locale(:fr) { assert_equal "Noir Integral", @variant.display_name }
  end

  test "shows the translation in the other language" do
    I18n.with_locale(:en) { assert_equal "All Black", @variant.display_name }
  end

  # A shop that has not translated a colour yet must still see something.
  test "falls back to the stored name when no translation exists" do
    @variant.update!(translations: {})

    I18n.with_locale(:en) { assert_equal "Noir Integral", @variant.display_name }
  end

  test "an empty translation is treated as missing" do
    @variant.update!(translations: { "en" => { "name" => "" } })

    I18n.with_locale(:en) { assert_equal "Noir Integral", @variant.display_name }
  end

  test "the order line names the watch in the reader's language" do
    order = orders(:paid_order)
    order.product.update!(name: "Montre", translations: { "en" => { "name" => "Watch" } })
    order.update!(variant: @variant)

    I18n.with_locale(:en) { assert_equal "Watch - All Black", order.reload.line_item_name }
    I18n.with_locale(:fr) { assert_equal "Montre - Noir Integral", order.reload.line_item_name }
  end
end
