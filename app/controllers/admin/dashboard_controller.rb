module Admin
  class DashboardController < BaseController
    def show
      @stores = Store.order(:name)
      @selected_store = @stores.find_by(id: params[:store_id]) if params[:store_id].present?
      @orders = @selected_store ? @selected_store.orders : Order.all
      @dashboard_currency = @selected_store&.currency || Store::DEFAULT_CURRENCY
      @today = Time.zone.now.beginning_of_day
      @seven_days_ago = 7.days.ago
    end
  end
end
