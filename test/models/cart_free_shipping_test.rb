require "test_helper"

class CartFreeShippingTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @cart = Cart.new(store: @store, session: {})
    @variant = variants(:black)
  end

  def with_threshold(fee_cents:, threshold_cents:)
    @store.update!(settings: @store.settings.merge(
      "shipping_cents" => fee_cents, "free_shipping_threshold_cents" => threshold_cents
    ))
  end

  test "a store that never charges shipping always ships free" do
    with_threshold(fee_cents: 0, threshold_cents: 6000)
    @cart.add(@variant)

    assert @cart.free_shipping?
    assert_equal 0, @cart.shipping_cents
    assert_equal 0, @cart.free_shipping_remaining_cents
  end

  test "below the threshold the fee is charged and the gap is reported" do
    with_threshold(fee_cents: 900, threshold_cents: 100_000)
    @cart.add(@variant)

    assert_not @cart.free_shipping?
    assert_equal 900, @cart.shipping_cents
    assert_equal 100_000 - @cart.discounted_subtotal_cents, @cart.free_shipping_remaining_cents
    assert_operator @cart.free_shipping_progress, :<, 1.0
  end

  test "clearing the threshold waives the fee" do
    with_threshold(fee_cents: 900, threshold_cents: 1)
    @cart.add(@variant)

    assert @cart.free_shipping?
    assert_equal 0, @cart.shipping_cents
    assert_equal 0, @cart.free_shipping_remaining_cents
    assert_in_delta 1.0, @cart.free_shipping_progress
  end

  test "the threshold is read after the discount, not before" do
    with_threshold(fee_cents: 900, threshold_cents: 100_000)
    @cart.add(@variant, quantity: 2)

    assert_equal @cart.subtotal_cents - @cart.discount_cents, @cart.discounted_subtotal_cents
  end

  test "an empty cart is never charged shipping" do
    with_threshold(fee_cents: 900, threshold_cents: 100_000)

    assert_equal 0, @cart.shipping_cents
  end

  test "without a threshold the flat fee always applies" do
    @store.update!(settings: @store.settings.merge(
      "shipping_cents" => 900, "free_shipping_threshold_cents" => 0
    ))
    @cart.add(@variant, quantity: 20)

    assert_not @cart.free_shipping?
    assert_equal 900, @cart.shipping_cents
    assert_equal 0, @cart.free_shipping_remaining_cents
  end
end
