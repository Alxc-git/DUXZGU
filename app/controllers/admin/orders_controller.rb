module Admin
  class OrdersController < BaseController
    before_action :set_order, only: %i[show retry_fulfillment repair_fulfillment mark_shipped refund]

    def index
      @stores = Store.order(:name)
      @orders = Order.includes(:store, :product, :customer).recent
      @orders = @orders.where(store_id: params[:store_id]) if params[:store_id].present?
      @orders = @orders.where(status: params[:status]) if params[:status].present?
      @orders = @orders.where(supplier_status: params[:supplier_status]) if params[:supplier_status].present?
      @orders = @orders.where("email ILIKE ?", "%#{params[:email]}%") if params[:email].present?
      @orders = @orders.where(created_at: Date.parse(params[:date]).all_day) if params[:date].present?
    rescue Date::Error
      @orders = @orders.none
    end

    def show; end

    def retry_fulfillment
      FulfillOrderJob.perform_later(@order.id)
      redirect_to admin_order_path(@order), notice: "Fulfillment retry queued"
    end

    def repair_fulfillment
      phone = params.dig(:order, :phone).to_s
      unless ShippingPhone.valid?(phone)
        redirect_to admin_fulfillment_path, alert: "Entrez un numero de telephone valide (6 a 32 chiffres)."
        return
      end

      normalized = ShippingPhone.normalize(phone)
      @order.update!(
        phone: normalized,
        supplier_status: nil,
        metadata: @order.metadata.except("fulfillment_error", "fulfillment_failed_at")
      )
      @order.customer&.update!(phone: normalized)
      FulfillOrderJob.perform_later(@order.id)

      redirect_to admin_fulfillment_path,
        notice: "Telephone enregistre. La commande ##{@order.id} est renvoyee a CJ."
    end

    def mark_shipped
      @order.update!(status: :shipped, shipped_at: Time.current)
      redirect_to admin_order_path(@order), notice: "Order marked shipped"
    end

    def refund
      Payments::RefundOrder.call(order: @order)
      redirect_to admin_order_path(@order), notice: "Refund created"
    rescue Payments::RefundOrder::Error, Stripe::StripeError => e
      redirect_to admin_order_path(@order), alert: e.message
    end

    private

    def set_order
      @order = Order.find(params[:id])
    end
  end
end
