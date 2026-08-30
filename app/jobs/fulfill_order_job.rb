class FulfillOrderJob < ApplicationJob
  queue_as :default

  retry_on Suppliers::Cj::Client::Error, wait: :polynomially_longer, attempts: 5

  def perform(order_id)
    order = Order.includes(:store, :product, :variant).find(order_id)
    return unless order.fulfillable?

    Suppliers.for(order.store).create_order(order)
    order.update!(status: :submitted_to_supplier) unless order.submitted_to_supplier?
  rescue Suppliers::UnsupportedSupplier, Suppliers::InvalidOrder => e
    # Not retryable: the order needs a human before it can ever be fulfilled.
    #
    # The payment status is deliberately left alone. Only a `fulfillable?` order
    # reaches this point, so the customer has already paid; marking it `failed`
    # would erase that. `supplier_status` records the problem instead, and the
    # admin's `supplier_errors` scope reads that field too.
    Rails.logger.error("[Fulfillment] #{e.message}")
    record_failure(order, e)
  rescue Suppliers::Cj::Client::Error => e
    record_failure(order, e)
    raise e
  end

  private

  def record_failure(order, error)
    return if order.blank?

    order.update!(
      supplier_status: "failed",
      metadata: order.metadata.merge(
        "fulfillment_error" => error.message.to_s.first(500),
        "fulfillment_failed_at" => Time.current.iso8601
      )
    )
  end
end
