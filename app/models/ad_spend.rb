# What one campaign cost on one day, typed in by hand.
#
# No ad platform is connected, and connecting one would not change what this is
# for: the dashboard needs the spend to turn profit-before-advertising into the
# only figure that decides whether an ad stays on.
class AdSpend < ApplicationRecord
  belongs_to :store

  # Matched against the attribution frozen on orders, which is lower-cased there
  # too, so "Facebook" typed in the form still lines up with "facebook" tagged in
  # the URL.
  before_validation :normalise

  validates :spent_on, :source, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :source, uniqueness: { scope: %i[store_id spent_on campaign] }

  scope :for_store, ->(store) { where(store:) }
  scope :between, ->(range) { where(spent_on: range) }
  scope :recent, -> { order(spent_on: :desc, source: :asc) }

  def formatted_amount
    MoneyFormatter.format(amount_cents, store.currency)
  end

  private

  def normalise
    self.source = source.to_s.strip.downcase.presence
    self.campaign = campaign.to_s.strip.downcase.presence
  end
end
