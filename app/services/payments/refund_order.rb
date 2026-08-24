module Payments
  class RefundOrder < ApplicationService
    Error = Class.new(StandardError)

    def initialize(order:)
      @order = order
    end

    def call
      raise Error, "Stripe is not configured" if Stripe.api_key.blank?
      raise Error, "Order has no Stripe payment intent" if order.stripe_payment_intent_id.blank?
      return order if order.refunded?

      Stripe::Refund.create({ payment_intent: order.stripe_payment_intent_id }, stripe_options)
      order.update!(status: :refunded, refunded_at: Time.current)
      order
    end

    private

    attr_reader :order

    def stripe_options
      order.store.stripe_account_id.present? ? { stripe_account: order.store.stripe_account_id } : {}
    end
  end
end
