class Variant < ApplicationRecord
  belongs_to :product
  has_many :orders, dependent: :restrict_with_error
  has_one_attached :image

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

  def swatch_color
    color_hex.presence || "#d4d4d8"
  end

  private

  def set_position
    siblings = product&.variants&.to_a&.reject { |variant| variant.equal?(self) } || []
    self.position = (siblings.filter_map { |variant| variant[:position] }.max || 0) + 1
  end
end
