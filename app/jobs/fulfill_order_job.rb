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
    order&.update!(supplier_status: "failed")
  rescue Suppliers::Cj::Client::Error => e
    order&.update!(supplier_status: "failed")
    raise e
  end
end
