class Store < ApplicationRecord
  SUPPLIER_TYPES = %w[cj].freeze
  DEFAULT_CURRENCY = "cad".freeze
  DEFAULT_LOCALE = "fr-CA".freeze
  DEFAULT_SHIPPING_COUNTRIES = %w[CA].freeze
  DEFAULT_SUPPORT_EMAIL = "contact@luxtimestyle.com".freeze
  PUBLIC_SETTING_KEYS = %w[
    legal_business_name business_address business_phone privacy_officer_name
    instagram_url tiktok_url facebook_url
  ].freeze

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
    return single_store_fallback(host) unless Rails.env.development? || Rails.env.test?
    return active.first if Rails.env.development?
    return active.first if host.in?(%w[localhost 127.0.0.1 0.0.0.0])

    nil
  end

  # A freshly deployed shop answers on a hostname nobody has recorded yet, and
  # returning nothing there takes the whole storefront down. With exactly one
  # active store the intent is unambiguous, so it is served and the mismatch is
  # logged. From the second store on, the domain has to match: guessing would
  # show one shop's prices under another's name.
  def self.single_store_fallback(host)
    return unless active.count == 1

    store = active.first
    Rails.logger.warn("[Store] no store matches host #{host.inspect}; falling back to #{store.domain.inspect}")
    store
  end
  private_class_method :single_store_fallback

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
    settings["support_email"].presence || (DEFAULT_SUPPORT_EMAIL if luxtime_store?)
  end

  def support_email=(value)
    write_public_setting("support_email", value)
  end

  PUBLIC_SETTING_KEYS.each do |key|
    define_method(key) { settings[key].presence }
    define_method("#{key}=") { |value| write_public_setting(key, value) }
  end

  def fulfillment_delay_minutes
    minutes = supplier_settings["fulfillment_delay_minutes"].to_i
    return 30 if minutes <= 0

    [ minutes, 240 ].min
  end


  # The CJ prepaid balance, as last recorded by hand.
  #
  # CJ exposes no balance endpoint, so this is what the shop typed in after its
  # last top-up. It is deliberately a recorded figure and not a live one: the
  # dashboard subtracts what has been spent since, and says when it was entered,
  # rather than pretending to know the real balance.
  def cj_balance_cents
    supplier_settings["cj_balance_cents"].to_i
  end

  def cj_balance_recorded_at
    value = supplier_settings["cj_balance_recorded_at"]
    Time.zone.parse(value.to_s) if value.present?
  end

  def record_cj_balance!(cents)
    update!(supplier_settings: supplier_settings.merge(
      "cj_balance_cents" => cents.to_i,
      "cj_balance_recorded_at" => Time.current.iso8601
    ))
  end
  private

  def write_public_setting(key, value)
    updated = settings.deep_dup
    normalized = value.to_s.strip.presence
    normalized ? updated[key] = normalized : updated.delete(key)
    self.settings = updated
  end

  def luxtime_store?
    slug == "luxtime" || name.to_s.casecmp?("LUXTIME") || domain.to_s.end_with?("luxtimestyle.com")
  end

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
