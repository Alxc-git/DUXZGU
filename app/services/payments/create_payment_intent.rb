module Payments
  # One PaymentIntent covers the whole checkout, even when the cart produced
  # several orders: the customer pays once. `automatic_payment_methods` is what
  # turns on cards, Apple Pay, Google Pay, Link and PayPal — which of them show up
  # is decided by the payment methods enabled in the Stripe dashboard, not here.
  class CreatePaymentIntent < ApplicationService
    Error = Class.new(StandardError)

    def initialize(store:, orders:, details:)
      @store = store
      @orders = Array(orders)
      @details = details
    end

    def call
      raise Error, "Stripe n'est pas configure" unless Payments.configured?
      raise Error, "Aucune commande a payer" if orders.empty?

      intent = Stripe::PaymentIntent.create(intent_params, stripe_options)

      orders.each do |order|
        order.update!(status: :checkout_created, stripe_payment_intent_id: intent.id)
      end

      intent
    rescue Stripe::StripeError => e
      raise Error, "Le paiement n'a pas pu etre initialise : #{e.message}"
    end

    private

    attr_reader :store, :orders, :details

    def intent_params
      {
        amount: total_cents,
        currency: orders.first.currency,
        automatic_payment_methods: { enabled: true },
        receipt_email: details.email.presence,
        description: orders.map(&:line_item_name).join(", ").truncate(300),
        shipping: shipping,
        metadata: reference_metadata
      }.compact
    end

    def total_cents
      orders.sum(&:total_cents)
    end

    def shipping
      {
        name: details.full_name.presence || "Client",
        phone: details.phone.presence,
        address: {
          line1: details.address_line1,
          line2: details.address_line2.presence,
          city: details.city,
          state: details.province.presence,
          postal_code: details.postal_code,
          country: details.country
        }.compact
      }.compact
    end

    # `order_ids` is what lets the webhook mark every order of this checkout paid.
    def reference_metadata
      {
        store_id: store.id,
        checkout_reference: orders.first.metadata["checkout_reference"],
        order_ids: orders.map(&:id).join(",")
      }.compact
    end

    def stripe_options
      store.stripe_account_id.present? ? { stripe_account: store.stripe_account_id } : {}
    end
  end
end
