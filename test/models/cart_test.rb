require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @session = {}
    @cart = Cart.new(store: @store, session: @session)
  end

  test "starts empty" do
    assert_predicate @cart, :empty?
    assert_equal 0, @cart.count
    assert_equal 0, @cart.total_cents
  end

  test "adding the same colour twice sums the quantities into one line" do
    @cart.add(variants(:black), quantity: 1)
    @cart.add(variants(:black), quantity: 2)

    assert_equal 1, @cart.lines.size
    assert_equal 3, @cart.count
  end

  test "each colour keeps its own line" do
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    assert_equal 2, @cart.lines.size
    assert_equal [ variants(:black).id, variants(:blue).id ], @cart.variant_ids
  end

  test "a variant price overrides the product price" do
    @cart.add(variants(:blue), quantity: 2)

    assert_equal 5400, @cart.lines.first.unit_price_cents
    assert_equal 10_800, @cart.subtotal_cents
  end

  test "quantity is capped rather than accepted unbounded" do
    @cart.set(variants(:black).id, 500)

    assert_equal Cart::MAX_QUANTITY, @cart.count
  end

  test "setting a quantity to zero drops the line" do
    @cart.add(variants(:black))
    @cart.set(variants(:black).id, 0)

    assert_predicate @cart, :empty?
  end

  test "removing a line empties the cart" do
    @cart.add(variants(:black))
    @cart.remove(variants(:black).id)

    assert_predicate @cart, :empty?
  end

  test "shipping is counted once for the whole cart, not per line" do
    @store.update!(settings: @store.settings.merge("shipping_cents" => 900))
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    assert_equal 900, @cart.shipping_cents
    assert_equal @cart.subtotal_cents + 900, @cart.total_cents
  end

  test "a variant from another store never appears in the cart" do
    @session["cart"] = { variants(:other_variant).id.to_s => 1 }

    assert_predicate @cart, :empty?
  end

  test "a deactivated variant drops out of the cart" do
    @cart.add(variants(:black))
    variants(:black).update!(active: false)

    assert_predicate Cart.new(store: @store, session: @session), :empty?
  end

  test "prices are read fresh, never carried by the session" do
    @cart.add(variants(:black))
    products(:demo_product).update!(price_cents: 9900)

    assert_equal 9900, Cart.new(store: @store, session: @session).subtotal_cents
  end

  test "clearing wipes the session entry" do
    @cart.add(variants(:black))
    @cart.clear

    assert_predicate @cart, :empty?
    assert_not @session.key?("cart")
  end
end
