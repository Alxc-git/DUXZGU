# Session-backed cart. Only variant ids and quantities are stored, so prices,
# names and photos are always read fresh from the database and a price change
# can never be carried by a stale session.
class Cart
  SESSION_KEY = "cart".freeze
  MAX_QUANTITY = 99

  Line = Data.define(:variant, :quantity) do
    def product
      variant.product
    end

    def unit_price_cents
      variant.price_cents
    end

    def total_cents
      unit_price_cents * quantity
    end

    def formatted_unit_price
      MoneyFormatter.format(unit_price_cents, variant.currency)
    end

    def formatted_total
      MoneyFormatter.format(total_cents, variant.currency)
    end
  end

  def initialize(store:, session:)
    @store = store
    @session = session
  end

  # Insertion order is kept, so a line never jumps around as quantities change.
  def lines
    @lines ||= stored.filter_map do |variant_id, quantity|
      variant = purchasable[variant_id.to_i]
      next if variant.blank? || quantity.to_i <= 0

      Line.new(variant:, quantity: quantity.to_i)
    end
  end

  def add(variant, quantity: 1)
    return if variant.blank?

    write(variant.id, stored[variant.id.to_s].to_i + quantity.to_i)
  end

  def set(variant_id, quantity)
    write(variant_id, quantity)
  end

  def remove(variant_id)
    write(variant_id, 0)
  end

  def clear
    @session.delete(SESSION_KEY)
    reset
  end

  def empty?
    lines.empty?
  end

  def any?
    lines.any?
  end

  def count
    lines.sum(&:quantity)
  end

  def variant_ids
    lines.map { |line| line.variant.id }
  end

  def subtotal_cents
    lines.sum(&:total_cents)
  end

  # A shipping fee is per parcel, not per line, so it is counted once.
  def shipping_cents
    empty? ? 0 : store.shipping_cents
  end

  def total_cents
    subtotal_cents + shipping_cents
  end

  def currency
    store.currency
  end

  def formatted_subtotal
    MoneyFormatter.format(subtotal_cents, currency)
  end

  def formatted_shipping
    MoneyFormatter.format(shipping_cents, currency)
  end

  def formatted_total
    MoneyFormatter.format(total_cents, currency)
  end

  private

  attr_reader :store, :session

  # Guards every read: a variant that was retired, deactivated or belongs to
  # another store simply disappears from the cart instead of being purchasable.
  def purchasable
    @purchasable ||= begin
      ids = stored.keys.map(&:to_i)

      if ids.empty? || store.blank?
        {}
      else
        Variant.active
               .where(id: ids)
               .joins(:product)
               .where(products: { store_id: store.id, active: true })
               .includes(:product, image_attachment: :blob)
               .index_by(&:id)
      end
    end
  end

  def write(variant_id, quantity)
    quantity = quantity.to_i.clamp(0, MAX_QUANTITY)
    data = stored.dup

    quantity.zero? ? data.delete(variant_id.to_s) : data[variant_id.to_s] = quantity

    session[SESSION_KEY] = data
    reset
  end

  def stored
    value = session[SESSION_KEY]
    value.is_a?(Hash) ? value : {}
  end

  def reset
    @lines = nil
    @purchasable = nil
  end
end
