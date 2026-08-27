# One storefront page view. A row is written for every page a visitor opens; the
# first of a session carries `landing`, which is what the dashboard counts as a
# visit. Nothing identifying is kept — no IP, no third-party cookie — so the
# figures need no consent banner.
class Visit < ApplicationRecord
  DEVICES = %w[mobile tablet desktop].freeze
  RETENTION_PERIOD = 13.months

  belongs_to :store

  validates :visitor_token, :path, presence: true
  validates :device, inclusion: { in: DEVICES }

  scope :for_store, ->(store) { where(store:) }
  scope :between, ->(range) { where(created_at: range) }
  scope :landings, -> { where(landing: true) }

  # Traffic that arrived from somewhere other than the site itself.
  scope :with_referrer, -> { where.not(referrer_host: nil) }
end
