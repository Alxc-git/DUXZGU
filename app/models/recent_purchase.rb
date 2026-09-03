# Social proof drawn from orders that actually happened. Nothing here is
# generated: if the store has no recent paid orders, the caller gets an empty
# list and the widget does not render.
#
# Only an initial and a city are published. A full first name next to a city is
# enough to identify a real customer in a small town, and the notice reads just as
# credible without it.
class RecentPurchase
  WINDOW = 30.days
  LIMIT = 12

  Entry = Data.define(:who, :city, :country, :quantity, :at) do
    def where
      [ city, country ].compact_blank.join(", ").presence
    end

    def to_h
      { who:, where:, quantity:, at: at.iso8601 }
    end
  end

  def self.for(store, limit: LIMIT)
    return [] if store.blank?

    store.orders
         .where.not(paid_at: nil)
         .where(paid_at: WINDOW.ago..)
         .order(paid_at: :desc)
         .limit(limit)
         .filter_map { |order| entry_for(order) }
  end

  def self.entry_for(order)
    city = order.city.to_s.strip.presence
    return if city.blank?

    Entry.new(
      who: initial_for(order),
      city:,
      country: order.country.to_s.strip.upcase.presence,
      quantity: order.quantity.to_i.clamp(1, 99),
      at: order.paid_at
    )
  end

  def self.initial_for(order)
    first = order.first_name.to_s.strip
    return "Someone" if first.blank?

    "#{first[0].upcase}."
  end
end
