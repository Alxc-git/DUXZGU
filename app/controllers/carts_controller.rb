class CartsController < ApplicationController
  before_action :require_current_store!

  def show
    # The colours not already in the cart, offered as a one-click add.
    @suggestions = current_product&.available_variants.to_a.reject do |variant|
      current_cart.variant_ids.include?(variant.id)
    end
  end

  def create
    variant = requested_variant

    if variant.blank?
      return redirect_back fallback_location: root_path, alert: "Cette couleur n'est plus disponible"
    end

    current_cart.add(variant, quantity: quantity_param)

    # "Acheter maintenant" adds the line then goes straight to the address form.
    if params[:then] == "checkout"
      redirect_to checkout_path
    else
      redirect_to cart_path,
        notice: "✨ Ajoute au panier - #{variant.product.name} (#{variant.name}). Checkout securise et livraison suivie."
    end
  end

  def update
    current_cart.set(params[:variant_id], quantity_param)
    redirect_to cart_path
  end

  def destroy
    current_cart.remove(params[:variant_id])
    redirect_to cart_path, notice: "Article retire du panier"
  end

  private

  # Only a variant of an active product of this store can enter the cart, and an
  # unknown id is refused rather than silently swapped for the default colour.
  def requested_variant
    product = Current.store.products.active.find_by(id: params[:product_id])
    return if product.blank?

    product.variant_for(params[:variant_id])
  end

  def quantity_param
    params[:quantity].presence || 1
  end
end
