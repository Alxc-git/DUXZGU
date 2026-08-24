require "test_helper"

class VariantTest < ActiveSupport::TestCase
  test "inherits price and supplier ids from the product when not overridden" do
    variant = variants(:black)

    assert_equal products(:demo_product).price_cents, variant.price_cents
    assert_equal products(:demo_product).compare_at_price_cents, variant.compare_at_price_cents
    assert_equal "cj-variant-black", variant.supplier_variant_id
  end

  test "overrides the product price when it has its own" do
    assert_equal 5_400, variants(:blue).price_cents
    assert_equal "54,00 $", variants(:blue).formatted_price
  end

  test "rejects a malformed swatch colour" do
    variant = variants(:black)
    variant.color_hex = "dark blue"

    assert_not variant.valid?
  end

  test "rejects two variants sharing a supplier variant id on the same product" do
    duplicate = products(:demo_product).variants.build(name: "Noir mat", supplier_variant_id: "cj-variant-black")

    assert_not duplicate.valid?
  end

  test "product exposes only active variants and defaults to the first" do
    product = products(:demo_product)
    assert_equal [ variants(:black), variants(:blue) ], product.available_variants
    assert_equal variants(:black), product.default_variant

    variants(:black).update!(active: false)

    assert_equal variants(:blue), product.reload.default_variant
  end

  test "product refuses a variant id belonging to another product" do
    assert_nil products(:demo_product).variant_for(variants(:other_variant).id)
  end

  test "product falls back to the default variant when no id is given" do
    assert_equal variants(:black), products(:demo_product).variant_for(nil)
  end

  test "new variants are positioned after existing ones" do
    variant = products(:demo_product).variants.create!(name: "Rouge")

    assert_equal 3, variant.position
  end
end
