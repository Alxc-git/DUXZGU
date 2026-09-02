class Variant < ApplicationRecord
  include TranslatableName

  belongs_to :product
  has_many :orders, dependent: :restrict_with_error
  # `image` is the white-background packshot used by the pickers, where a uniform
  # cut-out matters; `lifestyle_image` is the dark editorial shot used wherever the
  # product is presented rather than chosen.
  has_one_attached :image
  has_one_attached :lifestyle_image
  has_many_attached :detail_images

  before_validation :set_position, if: -> { position.blank? || position.zero? }

  validates :name, presence: true
  validates :price_cents, :compare_at_price_cents, :supplier_cost_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 },
    allow_nil: true
  validates :color_hex, format: { with: /\A#(\h{3}|\h{6})\z/, message: "must be a hex color" }, allow_blank: true
  validates :supplier_variant_id, uniqueness: { scope: :product_id }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  delegate :currency, :store, to: :product

  def price_cents
    self[:price_cents] || product&.price_cents
  end

  def compare_at_price_cents
    self[:compare_at_price_cents] || product&.compare_at_price_cents
  end

  def supplier_cost_cents
    self[:supplier_cost_cents] || product&.supplier_cost_cents
  end

  def supplier_variant_id
    self[:supplier_variant_id].presence || product&.supplier_variant_id
  end

  def supplier_sku
    self[:supplier_sku].presence || product&.supplier_sku
  end

  def formatted_price
    MoneyFormatter.format(price_cents, currency)
  end

  def formatted_compare_at_price
    return if compare_at_price_cents.blank?

    MoneyFormatter.format(compare_at_price_cents, currency)
  end

  # Falls back to the product gallery so a variant without its own photo still renders.
  def display_image
    image.attached? ? image : product.images.first
  end

  # Editorial shot when there is one, otherwise the packshot, so callers never
  # have to branch on which photos a given option happens to have.
  def hero_image
    lifestyle_image.attached? ? lifestyle_image : display_image
  end

  def lifestyle?
    lifestyle_image.attached?
  end

  def swatch_color
    color_hex.presence || "#d4d4d8"
  end

  private

  def set_position
    siblings = product&.variants&.to_a&.reject { |variant| variant.equal?(self) } || []
    self.position = (siblings.filter_map { |variant| variant[:position] }.max || 0) + 1
  end
end
