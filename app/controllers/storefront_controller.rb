class StorefrontController < ApplicationController
  before_action :require_current_store!

  helper_method :current_product

  def home
    # No redirect when the store has no product: root is the redirect target,
    # so bouncing here would loop. The template renders an empty state instead.
    @product = current_product
  end

  def show
    @product = Current.store.products.active.includes(:variants).find_by!(slug: params[:slug])
    @variant = @product.variant_for(params[:couleur]) || @product.default_variant
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Produit indisponible"
  end

  def success; end

  def cancel; end

  private

  def current_product
    @current_product ||= Current.store.products.active.includes(:variants).order(:created_at).first
  end
end
