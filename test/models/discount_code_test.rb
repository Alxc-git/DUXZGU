require "test_helper"

class DiscountCodeTest < ActiveSupport::TestCase
  setup { @store = stores(:demo) }

  def code(**attrs)
    DiscountCode.create!({ store: @store, code: "SAVE10", percent_off: 10 }.merge(attrs))
  end

  test "a code is found whatever the customer typed" do
    code

    assert_equal "SAVE10", DiscountCode.lookup(@store, "  save10 ")&.code
  end

  test "a code belongs to its own store" do
    code

    assert_nil DiscountCode.lookup(nil, "SAVE10")
  end

  test "a percentage is taken off the amount it applies to" do
    assert_equal 500, code.discount_on(5_000)
  end

  test "a fixed amount never exceeds the basket" do
    fixed = code(code: "TEN", percent_off: nil, amount_off_cents: 1_000)

    assert_equal 600, fixed.discount_on(600)
  end

  test "a code must be one kind of discount or the other" do
    assert_not DiscountCode.new(store: @store, code: "BOTH", percent_off: 10, amount_off_cents: 500).valid?
    assert_not DiscountCode.new(store: @store, code: "NEITHER").valid?
  end

  test "an expired code is refused and gives back the reason" do
    expired = code(code: "OLD", expires_at: 1.day.ago)

    assert_equal :expired, expired.rejection_for(5_000)
    assert_equal 0, expired.discount_on(5_000)
  end

  test "a code that hit its limit is refused" do
    spent = code(code: "GONE", usage_limit: 2, times_used: 2)

    assert_equal :exhausted, spent.rejection_for(5_000)
  end

  test "a minimum keeps a code off a small basket" do
    big = code(code: "BIG", minimum_cents: 6_000)

    assert_equal :minimum, big.rejection_for(5_000)
    assert big.usable_for?(6_000)
  end

  test "a deactivated code stops working without being deleted" do
    off = code(code: "OFF", active: false)

    assert_equal :inactive, off.rejection_for(5_000)
    assert_nil DiscountCode.lookup(@store, "OFF")
  end

  test "two codes cannot share a name in one store" do
    code

    assert_not DiscountCode.new(store: @store, code: "save10", percent_off: 5).valid?
  end
end
