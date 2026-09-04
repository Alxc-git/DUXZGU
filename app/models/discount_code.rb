# A promo code. Percentage or fixed amount, never both.
#
# The cut is taken on what the customer actually owes for the goods — after the
# volume offer, not before — so two discounts can never add up past the basket.
class DiscountCode < ApplicationRecord
  belongs_to :store

  # Codes are typed by hand off a newsletter or an ad, so they are stored and
  # compared upper-cased and stripped: "  promo10 " must find PROMO10.
  normalizes :code, with: ->(value) { value.to_s.strip.upcase }

  validates :code, presence: true, uniqueness: { scope: :store_id }
  validates :percent_off, numericality: { in: 1..100 }, allow_nil: true
  validates :amount_off_cents, numericality: { greater_than: 0 }, allow_nil: true
  validates :minimum_cents, :times_used, numericality: { greater_than_or_equal_to: 0 }
  validates :usage_limit, numericality: { greater_than: 0 }, allow_nil: true
  validate :exactly_one_kind_of_discount

  scope :usable, -> { where(active: true) }

  def self.lookup(store, code)
    return if store.blank? || code.to_s.strip.blank?

    usable.find_by(store:, code: code.to_s.strip.upcase)
  end

  def expired? = expires_at.present? && expires_at.past?
  def exhausted? = usage_limit.present? && times_used >= usage_limit
  def percentage? = percent_off.present?

  # Why this code cannot be used right now, or nil when it can. A single method so
  # the cart and the controller can never disagree about what counts as valid.
  def rejection_for(subtotal_cents)
    return :inactive unless active?
    return :expired if expired?
    return :exhausted if exhausted?
    return :minimum if subtotal_cents < minimum_cents

    nil
  end

  def usable_for?(subtotal_cents) = rejection_for(subtotal_cents).nil?

  # Never more than the amount it applies to: a $10 code on a $6 basket takes $6,
  # not $10, and certainly not a negative total.
  def discount_on(subtotal_cents)
    return 0 unless usable_for?(subtotal_cents)

    raw = percentage? ? (subtotal_cents * percent_off / 100.0).round : amount_off_cents
    raw.clamp(0, subtotal_cents)
  end

  def label
    percentage? ? "#{code} (-#{percent_off}%)" : code
  end

  private

  def exactly_one_kind_of_discount
    return if percent_off.present? ^ amount_off_cents.present?

    errors.add(:base, "set either a percentage or a fixed amount, not both")
  end
end
