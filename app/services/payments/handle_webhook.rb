module Payments
  class HandleWebhook < ApplicationService
    def initialize(event:)
      @event = event
    end

    def call
      case event.type
      when "checkout.session.completed"
        handle_checkout_completed(event.data.object)
      when "payment_intent.succeeded"
        handle_payment_intent_succeeded(event.data.object)
      when "payment_intent.payment_failed"
        handle_payment_intent_failed(event.data.object)
      when "charge.refunded"
        handle_charge_refunded(event.data.object)
      end
    end

    private

    attr_reader :event

    def handle_checkout_completed(session)
      order = Order.find_by(id: metadata(session)["order_id"])
      return if order.blank?

      enqueue_fulfillment = false

      Order.transaction do
        order.lock!
        return if order.submitted_to_supplier? || order.shipped? || order.delivered?

        enqueue_fulfillment = !order.metadata["fulfillment_job_enqueued"]
        customer = upsert_customer(order, session)
        details = object_hash(session.customer_details)
        shipping = shipping_details(session)
        address = object_hash(shipping["address"]).presence || object_hash(details["address"])
        names = split_name(shipping["name"].presence || details["name"])

        order.update!(
          customer: customer,
          status: :paid,
          paid_at: order.paid_at || Time.current,
          email: details["email"].presence || session.customer_email || order.email,
          first_name: names.first,
          last_name: names.last,
          phone: details["phone"],
          address_line1: address["line1"],
          address_line2: address["line2"],
          city: address["city"],
          province: address["state"],
          postal_code: address["postal_code"],
          country: address["country"],
          stripe_checkout_session_id: session.id,
          stripe_payment_intent_id: session.payment_intent,
          stripe_customer_id: session.customer,
          metadata: order.metadata.merge("fulfillment_job_enqueued" => true),
          **charged_amounts(session)
        )
      end

      FulfillOrderJob.perform_later(order.id) if enqueue_fulfillment
    end

    # Shipping address moved to collected_information in recent API versions; older
    # webhook endpoints still send it at the top level, so both shapes are read.
    def shipping_details(session)
      collected = object_hash(session.try(:collected_information))
      object_hash(collected["shipping_details"]).presence || object_hash(session.try(:shipping_details))
    end

    # Trust Stripe over our own pre-checkout estimate: this is what the customer paid.
    def charged_amounts(session)
      totals = object_hash(session.try(:total_details))
      shipping_cost = object_hash(session.try(:shipping_cost))

      {
        subtotal_cents: session.try(:amount_subtotal),
        tax_cents: totals["amount_tax"],
        shipping_cents: shipping_cost["amount_total"],
        total_cents: session.try(:amount_total),
        currency: session.try(:currency)
      }.compact
    end

    def handle_payment_intent_succeeded(intent)
      order = Order.find_by(id: metadata(intent)["order_id"]) || Order.find_by(stripe_payment_intent_id: intent.id)
      return if order.blank? || order.paid?

      order.update!(status: :paid, paid_at: Time.current, stripe_payment_intent_id: intent.id)
    end

    def handle_payment_intent_failed(intent)
      order = Order.find_by(id: metadata(intent)["order_id"]) || Order.find_by(stripe_payment_intent_id: intent.id)
      order&.update!(status: :failed, stripe_payment_intent_id: intent.id)
    end

    def handle_charge_refunded(charge)
      order = Order.find_by(stripe_payment_intent_id: charge.payment_intent)
      order&.update!(status: :refunded, refunded_at: Time.current)
    end

    def upsert_customer(order, session)
      details = object_hash(session.customer_details)
      email = details["email"].presence || session.customer_email || order.email
      return if email.blank?

      names = split_name(details["name"])
      order.store.customers.where(email: email.downcase).first_or_initialize.tap do |customer|
        customer.first_name = names.first if names.first.present?
        customer.last_name = names.last if names.last.present?
        customer.phone = details["phone"] if details["phone"].present?
        customer.stripe_customer_id = session.customer if session.customer.present?
        customer.save!
      end
    end

    def metadata(object)
      object_hash(object.metadata)
    end

    def object_hash(object)
      return {} if object.blank?
      return object.to_hash.stringify_keys if object.respond_to?(:to_hash)

      object.stringify_keys
    end

    def split_name(name)
      parts = name.to_s.squish.split(" ", 2)
      [ parts.first, parts.second ]
    end
  end
end
