module Admin
  class ProductsController < BaseController
    # Empty rows offered in the form so variants can be added without JavaScript.
    BLANK_VARIANT_ROWS = 3

    before_action :set_product, only: %i[show edit update destroy]

    def index
      @products = Product.includes(:store, :variants).order(created_at: :desc)
      @products = @products.where(store_id: params[:store_id]) if params[:store_id].present?
      @stores = Store.order(:name)
    end

    def show; end

    def new
      @product = Product.new(active: true, currency: Store::DEFAULT_CURRENCY)
      BLANK_VARIANT_ROWS.times { @product.variants.build }
      @stores = Store.order(:name)
    end

    def create
      @product = Product.new(product_params)
      if @product.save
        redirect_to admin_product_path(@product), notice: "Product created"
      else
        @stores = Store.order(:name)
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      BLANK_VARIANT_ROWS.times { @product.variants.build }
      @stores = Store.order(:name)
    end

    def update
      if @product.update(product_params)
        redirect_to admin_product_path(@product), notice: "Product updated"
      else
        @stores = Store.order(:name)
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @product.destroy
      redirect_to admin_products_path, notice: "Product deleted"
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.require(:product).permit(
        :store_id, :name, :slug, :description, :price_cents, :compare_at_price_cents, :currency,
        :active, :supplier_product_id, :supplier_variant_id, :supplier_sku, :supplier_cost_cents,
        images: [],
        variants_attributes: %i[
          id name color color_hex position active price_cents compare_at_price_cents
          supplier_cost_cents supplier_variant_id supplier_sku image _destroy
        ]
      )
    end
  end
end
