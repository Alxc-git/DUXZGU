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
    Rails.logger.error("[Fulfillment] #{e.message}")
    order&.update!(status: :failed, supplier_status: "failed")
  rescue Suppliers::Cj::Client::Error => e
    order&.update!(supplier_status: "failed")
    raise e
  end
end
