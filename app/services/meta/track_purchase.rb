module Meta
  # The one place a Purchase is raised.
  #
  # Every payment path converges on Payments::MarkOrdersPaid — the Stripe webhook,
  # the customer coming back from Stripe, the PayPal capture and the PayPal
  # webhook — and this runs from there, after the money is confirmed and never
  # before. A page view, a click on pay, or a failed attempt reaches nothing here.
  #
  # One Purchase per payment, not per order row: a two-variant cart is several Order
  # records behind a single charge, and Meta is told about the charge.
  #
  # Nothing raises out of `call`. Advertising must never be able to hold up a paid
  # order, so a failure is logged and the payment carries on.
  class TrackPurchase < ApplicationService
    GUARD = "meta_purchase_enqueued".freeze

    def initialize(orders:)
      @orders = Array(orders).compact
    end

    def call
      return if orders.empty? || !Meta.conversions_api_configured?

      group = payment_group
      return if group.empty? || !claim(group)

      MetaPurchaseJob.perform_later(group.map(&:id))
    rescue StandardError => e
      Rails.logger.error("[Meta CAPI] Purchase non transmis: #{e.class} #{e.message}")
      nil
    end

    private

    attr_reader :orders

    # MarkOrdersPaid is sometimes handed a single row of a checkout, so the whole
    # payment is loaded back: `value` has to be the amount actually charged, not
    # one line of it.
    #
    # `paid_at` rather than the status, for the reason the confirmation page gives:
    # an order already handed to the supplier, shipped or refunded was still paid.
    def payment_group
      Array(scope_for(orders.first)).select { |order| order.paid_at.present? }.sort_by(&:id)
    end

    def scope_for(order)
      store = order.store

      if order.stripe_payment_intent_id.present?
        store.orders.where(stripe_payment_intent_id: order.stripe_payment_intent_id)
      elsif order.paypal_capture_id.present?
        store.orders.where(paypal_capture_id: order.paypal_capture_id)
      elsif order.paypal_order_id.present?
        store.orders.where(paypal_order_id: order.paypal_order_id)
      elsif order.metadata["checkout_reference"].present?
        store.orders.where("metadata->>'checkout_reference' = ?", order.metadata["checkout_reference"])
      else
        orders
      end
    end

    # Claimed under a row lock, so the webhook and the browser landing together
    # still enqueue once. The lock reloads the row, which is what makes the second
    # caller see the flag the first one wrote.
    def claim(group)
      first = group.first
      claimed = false

      Order.transaction do
        first.lock!
        next if first.metadata[GUARD]

        claimed = true
        group.each { |order| order.update_column(:metadata, order.metadata.merge(GUARD => true)) }
      end

      claimed
    end
  end
end
