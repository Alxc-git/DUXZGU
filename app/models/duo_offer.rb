# "The second one at -X%". For every pair of watches in the cart, the cheaper of
# the two is discounted, which is the reading a customer expects and the only one
# that stays fair when colours carry different prices.
#
# The percentage is a store setting, so a shop can change or switch off the offer
# without a deploy.
class DuoOffer
  DEFAULT_PERCENT = 20
  SETTING = "duo_discount_percent".freeze

  # One purchasable unit, kept alongside the line it came from so the discount can
  # be handed back per line when the orders are written.
  Unit = Struct.new(:key, :price_cents)

  attr_reader :percent

  def initialize(store)
    @percent = self.class.percent_for(store)
  end

  def self.percent_for(store)
    value = store&.settings&.dig(SETTING)
    return DEFAULT_PERCENT if value.nil?

    value.to_i.clamp(0, 100)
  end

  def active?
    percent.positive?
  end

  # How much comes off, and how much of it belongs to each line.
  #
  # `units` is a flat list of every unit in the cart. The cheapest half are the
  # discounted ones: with two watches at the same price it makes no difference,
  # and with two different prices the customer gets the reading that favours them
  # only where it should — the discount never exceeds half the units.
  def apply(units)
    return { total_cents: 0, per_key: Hash.new(0) } unless active? && units.size >= 2

    discounted = units.sort_by(&:price_cents).first(units.size / 2)
    per_key = Hash.new(0)

    discounted.each do |unit|
      per_key[unit.key] += cut_for(unit.price_cents)
    end

    { total_cents: per_key.values.sum, per_key: }
  end

  # Rounded per unit rather than on the sum, so the amounts written on the orders
  # always add back up to the discount shown in the cart.
  def cut_for(price_cents)
    (price_cents * percent / 100.0).round
  end

  def label
    "La deuxieme a -#{percent} %"
  end
end
