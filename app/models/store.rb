class Store < ApplicationRecord
  SUPPLIER_TYPES = %w[cj].freeze
  DEFAULT_CURRENCY = "cad".freeze
  DEFAULT_LOCALE = "fr-CA".freeze
  DEFAULT_SHIPPING_COUNTRIES = %w[CA].freeze

  has_many :products, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :customers, dependent: :restrict_with_error

  before_validation :normalize_domain
  before_validation :set_slug, if: -> { slug.blank? && name.present? }
  before_validation :normalize_currency

  validates :name, :domain, :slug, :currency, :supplier_type, presence: true
  validates :domain, uniqueness: { case_sensitive: false }
  validates :slug, uniqueness: true
  validates :supplier_type, inclusion: { in: SUPPLIER_TYPES }

  scope :active, -> { where(active: true) }

  def self.resolve(host)
    normalized = normalize_host(host)
    active.find_by(domain: normalized) || development_fallback(normalized)
  end

  def self.normalize_host(host)
    host.to_s.split(":").first.downcase
  end

  def self.development_fallback(host)
    return unless Rails.env.development? || Rails.env.test?
    return active.first if host.in?(%w[localhost 127.0.0.1 0.0.0.0])

    nil
  end

  def template
    settings.fetch("template", "default")
  end

  # Locale of the hosted Stripe Checkout page.
  def checkout_locale
    settings["checkout_locale"].presence || DEFAULT_LOCALE
  end

  # Countries the storefront ships to, as ISO 3166-1 alpha-2 codes.
  def shipping_countries
    codes = Array(settings["shipping_countries"]).map { |code| code.to_s.strip.upcase }.compact_blank
    codes.presence || DEFAULT_SHIPPING_COUNTRIES
  end

  # Shipping charged on top of the product price. Zero means shipping is already
  # baked into the price, which is the default for one-product dropshipping stores.
  def shipping_cents
    [ settings["shipping_cents"].to_i, 0 ].max
  end

  def free_shipping?
    shipping_cents.zero?
  end

  def support_email
    settings["support_email"].presence
  end

  private

  def normalize_domain
    self.domain = self.class.normalize_host(domain)
  end

  def set_slug
    self.slug = name.parameterize
  end

  def normalize_currency
    self.currency = currency.to_s.downcase.presence || DEFAULT_CURRENCY
  end
end
