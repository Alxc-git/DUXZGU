# A quantity tier on the product page: "1 jar / 2 jars / 3 jars".
#
# The totals are not a separate price list — they are the cart's own maths run
# ahead of time through DuoOffer, so what the tier advertises is exactly what the
# customer is charged.
class PackTier
  QUANTITIES = [ 1, 2, 3 ].freeze
  POPULAR_QUANTITY = 2

  attr_reader :quantity, :unit_price_cents, :discount_cents, :currency

  def self.for(variant, store, quantities: QUANTITIES)
    return [] if variant.blank?

    offer = VolumeOffer.for(store)
    quantities.map { |quantity| new(variant, offer, quantity) }
  end

  def initialize(variant, offer, quantity)
    @quantity = quantity
    @unit_price_cents = variant.price_cents.to_i
    @currency = variant.currency
    units = Array.new(quantity) { DuoOffer::Unit.new(:pack, @unit_price_cents) }
    @discount_cents = offer.apply(units)[:total_cents]
  end

  def list_cents = unit_price_cents * quantity
  def total_cents = list_cents - discount_cents
  def per_unit_cents = quantity.zero? ? 0 : (total_cents.to_f / quantity).round
  def saves? = discount_cents.positive?
  def popular? = quantity == POPULAR_QUANTITY
  def percent_off = list_cents.zero? ? 0 : ((discount_cents * 100.0) / list_cents).round

  def formatted_total = MoneyFormatter.format(total_cents, currency)
  def formatted_list = MoneyFormatter.format(list_cents, currency)
  def formatted_saving = MoneyFormatter.format(discount_cents, currency)
  def formatted_per_unit = MoneyFormatter.format(per_unit_cents, currency)

  def label
    I18n.t(quantity == 1 ? "store.pdp.jar" : "store.pdp.jars", count: quantity)
  end
end
