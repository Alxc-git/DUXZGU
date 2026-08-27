module Admin
  class StoresController < BaseController
    before_action :set_store, only: %i[show edit update destroy]

    def index
      @stores = Store.order(:name)
    end

    def show; end

    def new
      @store = Store.new(active: true, currency: "eur", supplier_type: "cj")
    end

    def create
      @store = Store.new(store_params)
      if @store.save
        redirect_to admin_store_path(@store), notice: "Store created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @store.update(store_params)
        redirect_to admin_store_path(@store), notice: "Store updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @store.destroy
      redirect_to admin_stores_path, notice: "Store deleted"
    end

    private

    def set_store
      @store = Store.find(params[:id])
    end

    def store_params
      params.require(:store).permit(
        :name, :domain, :slug, :currency, :supplier_type, :active, :stripe_account_id,
        :support_email, :legal_business_name, :business_address, :business_phone, :privacy_officer_name,
        :instagram_url, :tiktok_url, :facebook_url
      )
    end
  end
end
