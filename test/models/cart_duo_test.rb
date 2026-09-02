require "test_helper"

class CartDuoTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @session = {}
    @cart = Cart.new(store: @store, session: @session)
  end

  test "one unit is charged in full" do
    @cart.add(variants(:black))

    assert_equal 0, @cart.discount_cents
    assert_equal @cart.subtotal_cents, @cart.total_cents
    assert_equal 1, @cart.units_to_offer
  end

  test "two units earn the discount and the total reflects it" do
    @cart.add(variants(:black), quantity: 2)

    assert @cart.discount?
    assert_equal @cart.subtotal_cents - @cart.discount_cents, @cart.total_cents
    assert_equal 0, @cart.units_to_offer
  end

  test "two different options earn the discount too" do
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    assert @cart.discount?
  end

  test "the discount is split across the lines it came from" do
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    per_line = @cart.lines.sum { |line| @cart.discount_for(line) }
    assert_equal @cart.discount_cents, per_line
  end

  test "shipping is added after the discount, never discounted itself" do
    @store.update!(settings: @store.settings.merge("shipping_cents" => 1000))
    cart = Cart.new(store: @store, session: {})
    cart.add(variants(:black), quantity: 2)

    assert_equal cart.subtotal_cents - cart.discount_cents + 1000, cart.total_cents
  end

  test "removing the second unit removes the discount" do
    @cart.add(variants(:black), quantity: 2)
    assert @cart.discount?

    @cart.set(variants(:black).id, 1)

    assert_not @cart.discount?
    assert_equal @cart.subtotal_cents, @cart.total_cents
  end

  test "the total never goes below zero even at a full discount" do
    @store.update!(settings: @store.settings.merge(DuoOffer::SETTING => 100))
    cart = Cart.new(store: @store, session: {})
    cart.add(variants(:black), quantity: 2)

    assert_operator cart.total_cents, :>=, 0
  end
end
