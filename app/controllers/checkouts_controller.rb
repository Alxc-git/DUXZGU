class CheckoutsController < ApplicationController
  before_action :require_current_store!
  before_action :require_filled_cart!

  def new
    @form = CheckoutForm.new(country: default_country)
  end

  def create
    @form = CheckoutForm.new(form_params)

    return render :new, status: :unprocessable_entity unless @form.valid?

    # Re-submitting the address form replaces the previous attempt rather than
    # leaving a second set of unpaid orders behind.
    discard_unpaid_orders

    orders = Orders::PlaceFromCart.call(store: Current.store, cart: current_cart, details: @form)
    session[:checkout_order_ids] = orders.map(&:id)

    redirect_to payment_path
  end

  private

  def form_params
    params.require(:checkout_form).permit(*CheckoutForm::FIELDS)
  end

  def require_filled_cart!
    return if current_cart.any?

    redirect_to cart_path, alert: t("cart.empty_alert")
  end

  def default_country
    Current.store.shipping_countries.first
  end

  def discard_unpaid_orders
    ids = session[:checkout_order_ids]
    return if ids.blank?

    Current.store.orders
           .where(id: ids, status: %i[pending checkout_created])
           .destroy_all
  end
end
