class Order < ApplicationRecord
  belongs_to :store
  belongs_to :product
  belongs_to :variant, optional: true
  belongs_to :customer, optional: true

  STATUSES = {
    pending: "pending",
    checkout_created: "checkout_created",
    paid: "paid",
    processing: "processing",
    submitted_to_supplier: "submitted_to_supplier",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled",
    refunded: "refunded",
    failed: "failed"
  }.freeze

  enum :status, STATUSES, default: :pending

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :subtotal_cents, :shipping_cents, :tax_cents, :total_cents, :discount_cents,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validate :product_belongs_to_store
  validate :variant_belongs_to_product

  scope :for_store, ->(store) { where(store:) }
  scope :recent, -> { order(created_at: :desc) }
  scope :supplier_errors, -> { where(status: :failed).or(where(supplier_status: "failed")) }
  scope :created_since, ->(time) { where(created_at: time..) }

  def recalculate_totals!
    self.subtotal_cents = unit_price_cents * quantity
    # The duo discount is carried per row, so a multi-line checkout still adds up
    # to the total the customer was shown.
    self.total_cents = [ subtotal_cents - discount_cents + shipping_cents + tax_cents, 0 ].max
    self.currency = product.currency
  end

  def discount?
    discount_cents.positive?
  end

  def formatted_discount
    MoneyFormatter.format(discount_cents, currency)
  end

  # A variant may override the product price; without one the product price applies.
  def unit_price_cents
    variant&.price_cents || product.price_cents
  end

  # Follows the reader's language, which is what makes the confirmation email
  # name the watch the way the customer saw it when they bought it.
  def line_item_name
    [ product.display_name, variant&.display_name ].compact_blank.join(" - ")
  end

  # The supplier identifiers actually shipped, variant first.
  def supplier_variant_id
    variant&.supplier_variant_id.presence || product.supplier_variant_id
  end

  def supplier_sku
    variant&.supplier_sku.presence || product.supplier_sku
  end

  def total
    total_cents.to_i / 100.0
  end

  # The delivery window quoted by the carrier at checkout. Falls back to the
  # store's generic promise when CJ could not be reached that day, so a customer
  # is never left without an answer.
  DEFAULT_DELIVERY_DAYS = (7..14).freeze

  def delivery_window_days
    return DEFAULT_DELIVERY_DAYS if delivery_min_days.blank? || delivery_max_days.blank?

    (delivery_min_days..delivery_max_days)
  end

  def estimated_delivery_on
    from = (paid_at || created_at || Time.current).to_date

    (from + delivery_window_days.first)..(from + delivery_window_days.last)
  end

  def tracked?
    tracking_number.present?
  end

  def reference
    metadata["checkout_reference"].presence || "ORD-#{id}"
  end

  def formatted_total
    MoneyFormatter.format(total_cents, currency)
  end

  def customer_name
    [ first_name, last_name ].compact_blank.join(" ")
  end

  def fulfillable?
    paid? && supplier_order_id.blank?
  end

  private

  def product_belongs_to_store
    return if product.blank? || store.blank? || product.store_id == store_id

    errors.add(:product, "must belong to the order store")
  end

  def variant_belongs_to_product
    return if variant.blank? || product.blank? || variant.product_id == product_id

    errors.add(:variant, "must belong to the order product")
  end
end
