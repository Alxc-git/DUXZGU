class CartsController < ApplicationController
  before_action :require_current_store!

  def show
    @flavor = current_cart.lines.first&.flavor || Flavor.default
  end

  def create
    variant = requested_variant

    if variant.blank?
      return redirect_back fallback_location: root_path, alert: t("cart.expired")
    end

    current_cart.add(variant, quantity: quantity_param, flavor: requested_flavor)
    # Recorded here rather than on the click: the variant has been resolved and the
    # line is in the cart, so this can only ever report an add that happened. It
    # rides the flash because both branches below redirect.
    track_meta_event_after_redirect("AddToCart", Meta::Content.for_variant(variant, quantity: added_quantity))

    # "Acheter maintenant" adds the line then goes straight to the address form.
    if params[:then] == "checkout"
      redirect_to checkout_path
    else
      redirect_to cart_path,
        notice: t("cart.added", product: variant.product.display_name, colour: variant.display_name)
    end
  end

  def update
    current_cart.set(params[:variant_id], quantity_param)
    redirect_to cart_path
  end

  def destroy
    current_cart.remove(params[:variant_id])
    redirect_to cart_path, notice: t("cart.removed")
  end

  private

  # Only a variant of an active product of this store can enter the cart, and an
  # unknown id is refused rather than silently swapped for the default option.
  def requested_variant
    product = Current.store.products.active.find_by(id: params[:product_id])
    return if product.blank?

    product.variant_for(params[:variant_id])
  end

  def quantity_param
    params[:quantity].presence || 1
  end

  def requested_flavor
    Flavor.find(params[:flavor].to_s)
  end

  # What the cart actually took, which is what the event should say.
  def added_quantity
    quantity_param.to_i.clamp(1, Cart::MAX_QUANTITY)
  end
end
