module CheckoutsHelper
  # Only the countries a store actually ships to are offered, so the label map
  # covers the usual dropshipping destinations and falls back to the raw code.
  COUNTRY_NAMES = {
    "CA" => "Canada",
    "US" => "Etats-Unis",
    "FR" => "France",
    "BE" => "Belgique",
    "CH" => "Suisse",
    "LU" => "Luxembourg",
    "GB" => "Royaume-Uni"
  }.freeze

  def shipping_country_options
    current_store.shipping_countries.map { |code| [ COUNTRY_NAMES.fetch(code, code), code ] }
  end

  def country_name(code)
    COUNTRY_NAMES.fetch(code.to_s.upcase, code)
  end

  # The order summary is rendered from the cart before the address is taken, and
  # from the placed orders afterwards. Both are flattened to the same shape so one
  # partial can draw either.
  def summary_lines_from_cart(cart)
    cart.lines.map do |line|
      { variant: line.variant, product: line.product, quantity: line.quantity, amount: line.formatted_total }
    end
  end

  def summary_lines_from_orders(orders)
    orders.map do |order|
      {
        variant: order.variant,
        product: order.product,
        quantity: order.quantity,
        amount: MoneyFormatter.format(order.subtotal_cents, order.currency)
      }
    end
  end

  def summary_totals_from_cart(cart)
    { subtotal: cart.formatted_subtotal, shipping_cents: cart.shipping_cents, total: cart.formatted_total }
  end

  def summary_totals_from_orders(orders)
    currency = orders.first.currency

    {
      subtotal: MoneyFormatter.format(orders.sum(&:subtotal_cents), currency),
      shipping_cents: orders.sum(&:shipping_cents),
      total: MoneyFormatter.format(orders.sum(&:total_cents), currency)
    }
  end

  def field_class(form, attribute)
    form.errors[attribute].any? ? "input input--invalid" : "input"
  end

  def checkout_field_error(form, attribute)
    message = form.errors[attribute].first
    return if message.blank?

    tag.p(message, class: "field__error")
  end
end
