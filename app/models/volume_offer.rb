# "Buy more, save more": a percentage off the whole order once the cart reaches a
# quantity tier. It answers the same three calls as DuoOffer — `active?`, `apply`
# and `label` — so the cart, the checkout and the written orders do not care which
# offer a store runs.
#
# Tiers live in store settings as {"2" => 10, "3" => 20}, read as "2 or more: 10%".
# Without that setting the store keeps DuoOffer, so nothing changes by upgrading.
class VolumeOffer
  SETTING = "volume_discount_tiers".freeze
  DEFAULT_TIERS = { 2 => 10, 3 => 20 }.freeze

  Unit = DuoOffer::Unit

  attr_reader :tiers

  def self.configured?(store)
    store&.settings&.key?(SETTING)
  end

  # The offer a store actually runs. A store that has not opted into tiers keeps
  # the pairs offer it had before.
  def self.for(store)
    configured?(store) ? new(store) : DuoOffer.new(store)
  end

  def initialize(store)
    @tiers = self.class.tiers_for(store)
  end

  def self.tiers_for(store)
    raw = store&.settings&.dig(SETTING)
    return DEFAULT_TIERS if raw.blank?

    parsed = raw.to_h { |quantity, percent| [ quantity.to_i, percent.to_i.clamp(0, 100) ] }
    parsed.select { |quantity, percent| quantity >= 2 && percent.positive? }.sort.to_h
  rescue NoMethodError, TypeError
    DEFAULT_TIERS
  end

  def active?
    tiers.any?
  end

  # The best tier a given quantity qualifies for, as a percentage. Zero below the
  # first tier.
  def percent_for(quantity)
    tiers.select { |threshold, _| quantity >= threshold }.values.max.to_i
  end

  def percent
    tiers.values.max.to_i
  end

  # The cut is spread across every unit so each order row can carry its share, and
  # the last unit absorbs the rounding remainder — the parts always add back up to
  # the total shown in the cart.
  def apply(units)
    empty = { total_cents: 0, per_key: Hash.new(0) }
    return empty unless active?

    percent = percent_for(units.size)
    return empty unless percent.positive?

    subtotal = units.sum(&:price_cents)
    total = (subtotal * percent / 100.0).round
    return empty unless total.positive?

    { total_cents: total, per_key: spread(units, total, subtotal) }
  end

  def label
    I18n.t("offer.volume_label", percent:, default: "Save up to %{percent}%%" % { percent: })
  end

  private

  def spread(units, total, subtotal)
    per_key = Hash.new(0)
    running = 0

    units.each_with_index do |unit, index|
      cut = if index == units.size - 1
        total - running
      else
        (total * unit.price_cents / subtotal.to_f).round
      end
      running += cut
      per_key[unit.key] += cut
    end

    per_key
  end
end
