module Admin
  class CustomersController < BaseController
    before_action :set_customer, only: :show

    def index
      @stores = Store.order(:name)
      @customers = Customer.includes(:store).order(created_at: :desc)
      @customers = @customers.where(store_id: params[:store_id]) if params[:store_id].present?
      @customers = @customers.where("email ILIKE ?", "%#{params[:email]}%") if params[:email].present?
    end

    def show
      @orders = @customer.orders.includes(:store, :product).recent
    end

    private

    def set_customer
      @customer = Customer.find(params[:id])
    end
  end
end
