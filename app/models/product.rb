class Product < ApplicationRecord
  include TranslatableName

  # Storefront copy. Anything set under settings["content"] wins, so a store can
  # be re-skinned from the admin without touching the templates.
  # Numbers that are data rather than copy; the wording lives in
  # config/locales/product_*.yml so the storefront can be read in either language.
  DEFAULT_NUMBERS = { "rating" => 4.7, "reviews_count" => 128 }.freeze

  belongs_to :store
  has_many :orders, dependent: :restrict_with_error
  has_many :variants, -> { ordered }, dependent: :destroy, inverse_of: :product
  has_many_attached :images
  # Editorial images used by the dark content section on home and product pages.
  has_one_attached :craft_image
  has_one_attached :collection_image
  # Detail photos of the case, crown, back and strap shown beside the product image.
  has_many_attached :part_images

  # `all_blank` would keep the empty admin rows, whose `active` checkbox defaults
  # to true: a variant only counts once it is named or mapped to a supplier id.
  accepts_nested_attributes_for :variants, allow_destroy: true,
    reject_if: ->(attributes) { attributes["name"].blank? && attributes["supplier_variant_id"].blank? }

  before_validation :set_slug, if: -> { slug.blank? && name.present? }
  before_validation :inherit_currency

  validates :name, :slug, :price_cents, :currency, presence: true
  validates :slug, uniqueness: { scope: :store_id }
  validates :price_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :compare_at_price_cents, :supplier_cost_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 },
    allow_nil: true

  scope :active, -> { where(active: true) }
  scope :for_store, ->(store) { where(store:) }

  def available_variants
    variants.select(&:active?)
  end

  def variants?
    available_variants.any?
  end

  def default_variant
    available_variants.first
  end

  # Only variants belonging to this product may be purchased. A blank id means the
  # customer never saw a picker, so the default applies; an unknown id is rejected
  # rather than silently swapped, so a tampered id can never reach the supplier.
  def variant_for(variant_id)
    return default_variant if variant_id.blank?

    available_variants.find { |variant| variant.id == variant_id.to_i }
  end

  # Storefront copy with per-product overrides applied on top of the defaults.
  # Copy for the current language, with anything a store set in the admin winning
  # over it. Memoised per locale, because a page can be rendered in either.
  def content
    @content ||= {}
    @content[I18n.locale] ||= default_content.merge(settings["content"].presence || {})
  end

  def default_content
    translated = I18n.t("product_content", default: {}).deep_stringify_keys
    DEFAULT_NUMBERS.merge(translated)
  end

  def rating
    content["rating"].to_f
  end

  def reviews_count
    content["reviews_count"].to_i
  end

  def price
    price_cents.to_i / 100.0
  end

  def discount_percentage
    return if compare_at_price_cents.blank? || compare_at_price_cents <= price_cents

    (100.0 * (compare_at_price_cents - price_cents) / compare_at_price_cents).round
  end

  def formatted_price
    MoneyFormatter.format(price_cents, currency)
  end

  def formatted_compare_at_price
    return if compare_at_price_cents.blank?

    MoneyFormatter.format(compare_at_price_cents, currency)
  end

  private

  def set_slug
    self.slug = name.parameterize
  end

  def inherit_currency
    self.currency = currency.presence || store&.currency || Store::DEFAULT_CURRENCY
    self.currency = currency.downcase
  end
end
