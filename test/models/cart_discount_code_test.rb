require "test_helper"

class CartDiscountCodeTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @cart = Cart.new(store: @store, session: {})
    @variant = variants(:black)
    @cart.add(@variant, quantity: 2)
    @code = DiscountCode.create!(store: @store, code: "SAVE10", percent_off: 10)
  end

  test "applying a code takes it off the total" do
    before = @cart.total_cents

    assert_equal :ok, @cart.apply_discount_code("save10")
    assert_operator @cart.total_cents, :<, before
    assert_equal before - @cart.code_discount_cents, @cart.total_cents
  end

  test "the code applies after the volume offer, never before" do
    @cart.apply_discount_code("SAVE10")

    assert_equal @cart.subtotal_cents - @cart.discount_cents, @cart.offer_subtotal_cents
    assert_equal @code.discount_on(@cart.offer_subtotal_cents), @cart.code_discount_cents
  end

  test "an unknown code changes nothing" do
    before = @cart.total_cents

    assert_equal :unknown, @cart.apply_discount_code("NOPE")
    assert_equal before, @cart.total_cents
    assert_nil @cart.discount_code
  end

  test "a code below its minimum is refused" do
    @code.update!(minimum_cents: 1_000_000)

    assert_equal :minimum, @cart.apply_discount_code("SAVE10")
    assert_equal 0, @cart.code_discount_cents
  end

  test "a code that expires after being applied stops counting" do
    @cart.apply_discount_code("SAVE10")
    assert_predicate @cart.code_discount_cents, :positive?

    @code.update!(expires_at: 1.minute.ago)
    fresh = Cart.new(store: @store, session: { Cart::DISCOUNT_KEY => "SAVE10" })

    assert_nil fresh.discount_code
    assert_equal 0, fresh.code_discount_cents
  end

  test "removing a code restores the total" do
    before = @cart.total_cents
    @cart.apply_discount_code("SAVE10")
    @cart.remove_discount_code

    assert_equal before, @cart.total_cents
  end

  test "a code can never push the total below the shipping charged" do
    @store.update!(settings: @store.settings.merge("shipping_cents" => 0))
    @code.update!(percent_off: nil, amount_off_cents: 10_000_000)
    @cart.apply_discount_code("SAVE10")

    assert_equal 0, @cart.total_cents
  end

  test "free shipping is judged on what is actually paid for the goods" do
    @store.update!(settings: @store.settings.merge(
      "shipping_cents" => 900, "free_shipping_threshold_cents" => @cart.offer_subtotal_cents
    ))
    assert_predicate @cart, :free_shipping?

    @cart.apply_discount_code("SAVE10")

    assert_not @cart.free_shipping?, "a code that drops the basket below the threshold reinstates shipping"
  end
end
