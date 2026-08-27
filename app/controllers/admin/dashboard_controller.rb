module Admin
  class DashboardController < BaseController
    def show
      @stores = Store.order(:name)
      @selected_store = @stores.find_by(id: params[:store_id]) if params[:store_id].present?
      @report = Analytics::Report.new(store: @selected_store, days: params[:days])

      @recent_orders = order_scope.recent.includes(:product, :variant).limit(8)
      @attention = {
        supplier_errors: order_scope.supplier_errors.count,
        awaiting_fulfillment: order_scope.awaiting_supplier.count,
        unpaid: order_scope.where(paid_at: nil).where(created_at: 2.days.ago..).count
      }
    end

    private

    def order_scope
      @selected_store ? @selected_store.orders : Order.all
    end
  end
end
