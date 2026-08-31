# Delivers the Purchase to Meta out of band, so nothing about the payment, the
# confirmation email or the supplier handoff waits on Facebook being reachable.
class MetaPurchaseJob < ApplicationJob
  queue_as :default

  # A conversion is worth retrying for: Meta being briefly down would otherwise
  # cost the campaign its optimisation signal. Retrying is safe because the event
  # id is derived from the payment — Meta drops a duplicate rather than counting
  # the sale twice.
  retry_on Meta::ConversionsApi::Error, wait: :polynomially_longer, attempts: 5
  discard_on ActiveJob::DeserializationError

  SENT_AT = "meta_purchase_sent_at".freeze

  def perform(order_ids)
    orders = Order.includes(:store, :product, :variant).where(id: order_ids).order(:id).to_a
    return if orders.empty? || orders.first.metadata[SENT_AT].present?

    Meta::ConversionsApi.call(**Meta::PurchaseEvent.build(orders))

    stamp = Time.current.iso8601
    orders.each { |order| order.update_column(:metadata, order.metadata.merge(SENT_AT => stamp)) }
  end
end
