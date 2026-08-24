require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "recalculates totals from product price" do
    order = orders(:paid_order)
    order.quantity = 3
    order.recalculate_totals!

    assert_equal 14_700, order.total_cents
    assert_equal "147,00 $", order.formatted_total
  end

  test "prices from the variant when one overrides the product price" do
    order = orders(:paid_order)
    order.variant = variants(:blue)
    order.quantity = 2
    order.recalculate_totals!

    assert_equal 10_800, order.total_cents
  end

  test "rejects a product from another store" do
    order = orders(:paid_order)
    order.product = products(:other_product)

    assert_not order.valid?
  end

  test "rejects a variant from another product" do
    order = orders(:paid_order)
    order.variant = variants(:other_variant)

    assert_not order.valid?
  end

  test "falls back to product supplier ids without a variant" do
    order = orders(:paid_order)

    assert_nil order.variant
    assert_equal "cj-variant", order.supplier_variant_id
  end

  test "uses the variant supplier ids when a variant is selected" do
    order = orders(:paid_order)
    order.variant = variants(:black)

    assert_equal "cj-variant-black", order.supplier_variant_id
    assert_equal "CJ-SKU-BLACK", order.supplier_sku
  end
end
