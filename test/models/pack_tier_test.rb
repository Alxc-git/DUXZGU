require "test_helper"

class PackTierTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @store.update!(settings: @store.settings.merge(VolumeOffer::SETTING => { "2" => 10, "3" => 20 }))
    @variant = variants(:black)
  end

  test "a tier quotes what the cart would charge for that quantity" do
    tier = PackTier.for(@variant, @store).find { |t| t.quantity == 3 }

    cart = Cart.new(store: @store, session: {})
    cart.add(@variant, quantity: 3)

    assert_equal cart.subtotal_cents - cart.discount_cents, tier.total_cents
  end

  test "the single jar carries no discount" do
    tier = PackTier.for(@variant, @store).first

    assert_equal 1, tier.quantity
    assert_not tier.saves?
    assert_equal tier.list_cents, tier.total_cents
  end

  test "the per-jar price falls as the pack grows" do
    per_unit = PackTier.for(@variant, @store).map(&:per_unit_cents)

    assert_equal per_unit.sort.reverse, per_unit
  end

  test "one tier is flagged as the popular one" do
    assert_equal 1, PackTier.for(@variant, @store).count(&:popular?)
  end

  test "no variant means no tiers" do
    assert_empty PackTier.for(nil, @store)
  end
end
