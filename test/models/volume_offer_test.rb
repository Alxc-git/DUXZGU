require "test_helper"

class VolumeOfferTest < ActiveSupport::TestCase
  setup { @store = stores(:demo) }

  def tiered(tiers = { "2" => 10, "3" => 20 })
    @store.update!(settings: @store.settings.merge(VolumeOffer::SETTING => tiers))
    VolumeOffer.new(@store)
  end

  def units(*prices)
    prices.each_with_index.map { |price, index| VolumeOffer::Unit.new("line-#{index}", price) }
  end

  test "a store without tiers keeps the pairs offer" do
    assert_instance_of DuoOffer, VolumeOffer.for(@store)
  end

  test "a store with tiers gets the volume offer" do
    @store.update!(settings: @store.settings.merge(VolumeOffer::SETTING => { "2" => 10 }))

    assert_instance_of VolumeOffer, VolumeOffer.for(@store)
  end

  test "below the first tier nothing comes off" do
    assert_equal 0, tiered.apply(units(2499))[:total_cents]
  end

  test "each tier takes its percentage off the whole order" do
    offer = tiered

    assert_equal 500, offer.apply(units(2499, 2499))[:total_cents]
    assert_equal 1499, offer.apply(units(2499, 2499, 2499))[:total_cents]
  end

  test "a bigger basket never saves less than a smaller one" do
    offer = tiered
    totals = (1..5).map { |n| offer.apply(units(*Array.new(n, 2499)))[:total_cents] }

    assert_equal totals.sort, totals
  end

  test "the per-line shares add back up to the total" do
    result = tiered.apply(units(2499, 2499, 2499))

    assert_equal result[:total_cents], result[:per_key].values.sum
  end

  test "shares are split across lines in proportion to their price" do
    result = tiered.apply(units(9000, 1000, 1000))

    assert_operator result[:per_key]["line-0"], :>, result[:per_key]["line-1"]
    assert_equal result[:total_cents], result[:per_key].values.sum
  end

  test "tiers below two units or at zero percent are ignored" do
    offer = tiered({ "1" => 50, "2" => 0, "3" => 20 })

    assert_equal({ 3 => 20 }, offer.tiers)
    assert_equal 0, offer.apply(units(2499, 2499))[:total_cents]
  end

  test "a malformed setting falls back to the defaults" do
    @store.update!(settings: @store.settings.merge(VolumeOffer::SETTING => "nonsense"))

    assert_equal VolumeOffer::DEFAULT_TIERS, VolumeOffer.new(@store).tiers
  end
end
