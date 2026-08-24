class UpdateTrackingJob < ApplicationJob
  queue_as :default

  retry_on Suppliers::Cj::Client::Error, wait: :polynomially_longer, attempts: 3

  # CJ order statuses mapped onto our own lifecycle. Anything else (PENDING,
  # PROCESSING, UNSHIPPED...) means the order is still moving inside CJ.
  SUPPLIER_STATUS_MAP = {
    "SHIPPED" => :shipped,
    "DELIVERED" => :delivered,
    "CANCELLED" => :cancelled
  }.freeze

  def perform(order_id = nil)
    orders = order_id.present? ? Order.where(id: order_id) : trackable_orders
    orders.includes(:store).find_each { |order| update_order(order, raise_on_error: order_id.present?) }
  end

  private

  # Shipped orders stay in the sweep so delivery can still be picked up.
  def trackable_orders
    Order.where(status: %i[submitted_to_supplier shipped]).where.not(supplier_order_id: nil)
  end

  def update_order(order, raise_on_error:)
    tracking = Suppliers.for(order.store).tracking(order)
    attributes = tracking_attributes(tracking).merge(lifecycle_attributes(order, tracking))
    return if attributes.blank?

    order.update!(attributes)
  rescue Suppliers::Cj::Client::Error => e
    # One failing order must not stop the sweep for every other order.
    Rails.logger.error("[Tracking] order #{order.id}: #{e.message}")
    raise e if raise_on_error
  end

  def tracking_attributes(tracking)
    {
      tracking_number: tracking[:tracking_number],
      tracking_url: tracking[:tracking_url],
      supplier_status: tracking[:supplier_status]
    }.compact
  end

  def lifecycle_attributes(order, tracking)
    case SUPPLIER_STATUS_MAP[tracking[:supplier_status].to_s.upcase]
    when :shipped
      return {} if order.shipped?

      { status: :shipped, shipped_at: order.shipped_at || Time.current }
    when :delivered
      return {} if order.delivered?

      { status: :delivered, shipped_at: order.shipped_at || Time.current, delivered_at: Time.current }
    when :cancelled
      order.cancelled? ? {} : { status: :cancelled }
    else
      {}
    end
  end
end
