module Payments
  # Marks every order of one PaymentIntent paid and queues fulfillment once.
  #
  # Both the webhook and the return from Stripe run this, so it has to be safe to
  # run twice: an order already paid is skipped, and the fulfillment job is only
  # enqueued the first time.
  class MarkOrdersPaid < ApplicationService
    def initialize(intent_id:, orders: nil, metadata: {})
      @intent_id = intent_id
      @orders = orders
      @metadata = metadata.to_h.stringify_keys
    end

    def call
      orders = scope.to_a
      orders.each { |order| mark(order) }
      notify(orders)
      orders
    end

    private

    attr_reader :intent_id, :metadata

    # One confirmation for the whole checkout, not one per line, and only once:
    # the webhook and the browser both land here for the same payment.
    def notify(orders)
      first = orders.find { |order| order.paid? && order.email.present? }
      return if first.blank? || first.metadata["confirmation_sent"]

      OrderMailer.confirmation(orders.map(&:id)).deliver_later
      orders.each { |order| order.update_column(:metadata, order.metadata.merge("confirmation_sent" => true)) }
    rescue StandardError => e
      # A mail outage must never leave a paid order unrecorded.
      Rails.logger.error("[Commande] confirmation non envoyee: #{e.class} #{e.message}")
    end

    def scope
      return @orders if @orders.present?

      ids = metadata["order_ids"].to_s.split(",").map(&:to_i).reject(&:zero?)
      return Order.where(id: ids) if ids.any?

      Order.where(stripe_payment_intent_id: intent_id)
    end

    def mark(order)
      enqueue = false

      Order.transaction do
        order.lock!
        next if order.paid? || order.submitted_to_supplier? || order.shipped? || order.delivered?

        enqueue = !order.metadata["fulfillment_job_enqueued"]
        order.update!(
          {
            status: :paid,
            paid_at: order.paid_at || Time.current,
            metadata: order.metadata.merge(metadata).merge("fulfillment_job_enqueued" => true)
          }.merge(
            # A PayPal capture passes no intent id; writing nil here would erase
            # the reference of a Stripe attempt the customer made first.
            intent_id.present? ? { stripe_payment_intent_id: intent_id } : {}
          )
        )
      end

      Fulfillment::EnqueueOrder.call(order:) if enqueue
    end
  end
end
