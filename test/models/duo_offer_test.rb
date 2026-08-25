require "test_helper"

class DuoOfferTest < ActiveSupport::TestCase
  setup { @store = stores(:demo) }

  def units(*prices)
    prices.each_with_index.map { |price, index| DuoOffer::Unit.new("line-#{index}", price) }
  end

  test "a single watch earns nothing" do
    assert_equal 0, DuoOffer.new(@store).apply(units(5499))[:total_cents]
  end

  test "two watches discount one of them" do
    assert_equal 1100, DuoOffer.new(@store).apply(units(5499, 5499))[:total_cents]
  end

  test "three watches still discount only one" do
    assert_equal 1100, DuoOffer.new(@store).apply(units(5499, 5499, 5499))[:total_cents]
  end

  test "four watches discount two" do
    assert_equal 2200, DuoOffer.new(@store).apply(units(5499, 5499, 5499, 5499))[:total_cents]
  end

  test "the cheaper watch is the discounted one" do
    result = DuoOffer.new(@store).apply(units(9000, 4000))

    assert_equal 800, result[:total_cents]
  end

  test "the discount is attributed to the line it came from" do
    result = DuoOffer.new(@store).apply(units(9000, 4000))

    assert_equal 0, result[:per_key]["line-0"]
    assert_equal 800, result[:per_key]["line-1"]
  end

  test "the per-line amounts always add up to the total shown" do
    result = DuoOffer.new(@store).apply(units(3333, 3333, 3333, 3333))

    assert_equal result[:total_cents], result[:per_key].values.sum
  end

  test "a store can switch the offer off" do
    @store.update!(settings: @store.settings.merge(DuoOffer::SETTING => 0))
    offer = DuoOffer.new(@store)

    assert_not offer.active?
    assert_equal 0, offer.apply(units(5499, 5499))[:total_cents]
  end

  test "a store can change the percentage" do
    @store.update!(settings: @store.settings.merge(DuoOffer::SETTING => 50))
    offer = DuoOffer.new(@store)

    assert_equal 2750, offer.apply(units(5499, 5499))[:total_cents]
    assert_equal "La deuxieme a -50 %", offer.label
  end

  test "an out of range percentage is clamped rather than trusted" do
    @store.update!(settings: @store.settings.merge(DuoOffer::SETTING => 900))
    assert_equal 100, DuoOffer.new(@store).percent

    @store.update!(settings: @store.settings.merge(DuoOffer::SETTING => -20))
    assert_equal 0, DuoOffer.new(@store).percent
  end
end
