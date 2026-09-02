require "test_helper"

class Orders::PlaceFromCartTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @cart = Cart.new(store: @store, session: {})
    @details = CheckoutForm.new(
      email: "  Alexis@Exemple.CA ",
      first_name: "Alexis",
      last_name: "Giard",
      phone: "514 555 0123",
      address_line1: "123 rue Sainte-Catherine",
      city: "Montreal",
      province: "QC",
      postal_code: "H2X 1Y6",
      country: "CA"
    )
  end

  test "creates one order per cart line" do
    @cart.add(variants(:black), quantity: 2)
    @cart.add(variants(:blue))

    orders = place

    assert_equal 2, orders.size
    assert_equal [ 2, 1 ], orders.map(&:quantity)
    assert_equal [ variants(:black).id, variants(:blue).id ], orders.map(&:variant_id)
  end

  test "the orders of one checkout share a reference" do
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    references = place.map { |order| order.metadata["checkout_reference"] }

    assert_equal 1, references.uniq.size
    assert_match(/\ALX-[A-Z0-9]{8}\z/, references.first)
  end

  test "shipping is charged once, on the first line only" do
    @store.update!(settings: @store.settings.merge("shipping_cents" => 900))
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    assert_equal [ 900, 0 ], place.map(&:shipping_cents)
  end

  test "totals cover the quantity plus shipping minus discounts" do
    @store.update!(settings: @store.settings.merge("shipping_cents" => 900))
    @cart.add(variants(:black), quantity: 3)

    order = place.first

    assert_equal 7_497, order.subtotal_cents
    assert_equal order.subtotal_cents - order.discount_cents + order.shipping_cents, order.total_cents
  end

  test "the shipping address is copied onto every order" do
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    place.each do |order|
      assert_equal "Montreal", order.city
      assert_equal "123 rue Sainte-Catherine", order.address_line1
      assert_equal "Alexis Giard", order.customer_name
    end
  end

  test "orders stay pending: payment is a separate step" do
    @cart.add(variants(:black))

    assert_predicate place.first, :pending?
  end

  test "creates the customer once, with a normalised email" do
    @cart.add(variants(:black))
    @cart.add(variants(:blue))

    orders = nil
    assert_difference "Customer.count", 1 do
      orders = place
    end

    assert_equal 1, orders.map(&:customer_id).uniq.size
    assert_equal "alexis@exemple.ca", orders.first.customer.email
  end

  test "reuses an existing customer of the store" do
    existing = @store.customers.create!(email: "alexis@exemple.ca")
    @cart.add(variants(:black))

    assert_no_difference "Customer.count" do
      assert_equal existing.id, place.first.customer_id
    end
  end

  private

  def place
    Orders::PlaceFromCart.call(store: @store, cart: @cart, details: @details)
  end
end
