module Meta
  # Builds the Purchase payload from orders that are already paid for.
  #
  # The event id is derived from the payment itself rather than generated, which
  # is what makes a replayed webhook, a retried job and a customer refreshing the
  # confirmation page all resolve to the same event on Meta's side.
  module PurchaseEvent
    NAME = "Purchase".freeze

    module_function

    def build(orders)
      first = orders.first

      {
        event_name: NAME,
        event_id: event_id(orders),
        event_time: event_time(first),
        event_source_url: source_url(first),
        user_data: UserData.for_order(first),
        # `order_id` is the checkout reference, not a row id: it is the receipt the
        # customer and the admin both quote.
        custom_data: Content.for_orders(orders).merge(order_id: first.reference)
      }
    end

    # Unique per payment and stable across every path that reports it.
    def event_id(orders)
      first = orders.first

      return "purchase_stripe_#{first.stripe_payment_intent_id}" if first.stripe_payment_intent_id.present?
      return "purchase_paypal_#{first.paypal_capture_id}" if first.paypal_capture_id.present?
      return "purchase_paypal_order_#{first.paypal_order_id}" if first.paypal_order_id.present?

      "purchase_ref_#{first.reference}"
    end

    # When the money actually moved. Meta rejects an event dated more than seven
    # days back, which a long fulfillment retry could otherwise walk into.
    def event_time(order)
      (order.paid_at || order.updated_at || Time.current).to_i
    end

    # Where the customer was when they paid, captured at checkout. The store domain
    # is the fallback: a webhook has no request of its own to read.
    def source_url(order)
      order.metadata.dig(UserData::CONTEXT_KEY, "source_url").presence ||
        "https://#{order.store.domain}/"
    end
  end
end
