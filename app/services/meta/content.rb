module Meta
  # The `custom_data` block Meta optimises on, built from the catalogue and the
  # cart rather than from anything the browser sent.
  #
  # `content_ids` carries product ids, which is what a Meta catalogue built from
  # this store would be keyed on. If the catalogue is ever keyed on the variant or
  # the supplier SKU instead, `content_id_for` is the only method to change.
  module Content
    TYPE = "product".freeze

    module_function

    def for_product(product, variant: nil)
      priced = variant || product

      {
        content_type: TYPE,
        content_ids: [ content_id_for(product) ],
        content_name: product.display_name,
        value: amount(priced.price_cents),
        currency: currency_for(product.currency)
      }
    end

    def for_variant(variant, quantity: 1)
      product = variant.product

      {
        content_type: TYPE,
        content_ids: [ content_id_for(product) ],
        content_name: product.display_name,
        contents: [ line(product, variant.price_cents, quantity) ],
        value: amount(variant.price_cents * quantity),
        currency: currency_for(product.currency),
        num_items: quantity
      }
    end

    # `total_cents` rather than the subtotal: the duo discount and the shipping fee
    # are part of what the customer is about to be asked for.
    def for_cart(cart)
      {
        content_type: TYPE,
        content_ids: cart.lines.map { |cart_line| content_id_for(cart_line.product) }.uniq,
        contents: cart.lines.map { |cart_line| line(cart_line.product, cart_line.unit_price_cents, cart_line.quantity) },
        value: amount(cart.total_cents),
        currency: currency_for(cart.currency),
        num_items: cart.count
      }
    end

    # One payment covers every order row it produced, so the value is their sum.
    def for_orders(orders)
      {
        content_type: TYPE,
        content_ids: orders.map { |order| content_id_for(order.product) }.uniq,
        content_name: orders.first.product.display_name,
        contents: orders.map { |order| line(order.product, order.unit_price_cents, order.quantity) },
        value: amount(orders.sum(&:total_cents)),
        currency: currency_for(orders.first.currency),
        num_items: orders.sum(&:quantity)
      }
    end

    def content_id_for(product)
      product.id.to_s
    end

    def line(product, unit_price_cents, quantity)
      { id: content_id_for(product), quantity: quantity.to_i, item_price: amount(unit_price_cents) }
    end

    # Meta reads money as a decimal number, never as cents.
    def amount(cents)
      (cents.to_i / 100.0).round(2)
    end

    # Currency codes travel upper case: "cad" in the database, "CAD" to Meta.
    def currency_for(code)
      code.to_s.upcase
    end
  end
end
