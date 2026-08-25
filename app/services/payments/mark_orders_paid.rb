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
      scope.each { |order| mark(order) }
    end

    private

    attr_reader :intent_id, :metadata

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
