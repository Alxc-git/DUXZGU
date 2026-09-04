# Social proof drawn from orders that actually happened. Nothing here is
# generated: fabricating purchase notices is a misleading representation under
# the Competition Act in Canada and banned outright by the FTC's 2024 rule, and
# shoppers recognise the pattern anyway.
#
# Two shapes are offered, because a young store has no steady stream of orders:
#   - `for`      recent individual orders, the classic notice
#   - `summary`  a real count over a longer window, when there are too few
#
# The window and the name style are store settings: how much a shop chooses to
# publish about its own customers is the owner's call, not this file's.
class RecentPurchase
  DEFAULT_WINDOW_HOURS = 72
  SUMMARY_WINDOW = 30.days
  # Below this, individual notices read as "one lonely order" rather than as
  # momentum, so the aggregate is shown instead.
  MIN_FOR_NOTICES = 3
  LIMIT = 12

  WINDOW_SETTING = "social_proof_window_hours".freeze
  NAME_SETTING = "social_proof_names".freeze

  Entry = Data.define(:who, :city, :quantity, :at) do
    def to_h = { who:, city:, quantity:, at: at.iso8601 }
  end

  def self.window_for(store)
    hours = store&.settings&.dig(WINDOW_SETTING).to_i
    (hours.positive? ? hours : DEFAULT_WINDOW_HOURS).hours
  end

  # "initial" publishes `S.`, "first_name" publishes `Sophie`. The initial is the
  # default: a first name next to a city identifies a real person in a small town,
  # and the notice reads just as well without it.
  def self.name_style_for(store)
    style = store&.settings&.dig(NAME_SETTING).to_s
    style.in?(%w[initial first_name]) ? style : "initial"
  end

  def self.for(store, limit: LIMIT)
    return [] if store.blank?

    entries = paid_since(store, window_for(store))
                .limit(limit)
                .filter_map { |order| entry_for(order, name_style_for(store)) }

    entries.size >= MIN_FOR_NOTICES ? entries : []
  end

  # How many real orders the store took over the longer window. Nil when the
  # number is too small to mean anything.
  def self.summary(store, minimum: MIN_FOR_NOTICES)
    return if store.blank?

    count = paid_since(store, SUMMARY_WINDOW).count
    return if count < minimum

    { count:, days: SUMMARY_WINDOW.in_days.to_i }
  end

  def self.paid_since(store, window)
    store.orders
         .where.not(paid_at: nil)
         .where(paid_at: window.ago..)
         .order(paid_at: :desc)
  end

  def self.entry_for(order, name_style)
    city = order.city.to_s.strip.presence
    return if city.blank?

    Entry.new(
      who: display_name(order, name_style),
      city: city.titleize,
      quantity: order.quantity.to_i.clamp(1, 99),
      at: order.paid_at
    )
  end

  def self.display_name(order, name_style)
    first = order.first_name.to_s.strip.split.first
    return "Someone" if first.blank?

    name_style == "first_name" ? first.capitalize : "#{first[0].upcase}."
  end
end
