class CheckoutsController < ApplicationController
  before_action :require_current_store!
  before_action :require_filled_cart!

  def new
    @form = CheckoutForm.new(country: default_country)
    @flavor = Flavor.find(params[:flavor].to_s)
    @qty = params.fetch(:qty, current_cart.count.presence || 1).to_i.clamp(1, Cart::MAX_QUANTITY)

    # Only here, not on the re-render `create` does after a validation error: the
    # customer starts the checkout once.
    track_meta_event("InitiateCheckout", Meta::Content.for_cart(current_cart))
  end

  def create
    @form = CheckoutForm.new(form_params)
    @flavor = Flavor.find(params[:flavor].to_s)
    @qty = current_cart.count.presence || 1

    return render :new, status: :unprocessable_entity unless @form.valid?

    # Re-submitting the address form replaces the previous attempt rather than
    # leaving a second set of unpaid orders behind.
    discard_unpaid_orders

    orders = Orders::PlaceFromCart.call(store: Current.store, cart: current_cart, details: @form,
                                        attribution: session[TracksVisits::ATTRIBUTION_KEY],
                                        meta_context: meta_context)
    session[:checkout_order_ids] = orders.map(&:id)

    redirect_to payment_path
  end

  private

  def form_params
    params.require(:checkout_form).permit(*CheckoutForm::FIELDS)
  end

  # The browser signals Meta matches a Purchase on, captured while there is still
  # a request to read them from. A webhook confirming the payment hours later has
  # no cookies, no IP and no user agent of the customer's own.
  #
  # `_fbp` and `_fbc` are the pixel's own cookies, so they only exist once the
  # customer accepted analytics. Nothing is invented when they are absent.
  def meta_context
    {
      "fbp" => cookies["_fbp"],
      "fbc" => cookies["_fbc"],
      "client_ip_address" => request.remote_ip,
      "client_user_agent" => request.user_agent,
      "source_url" => request.original_url,
      # The choice as it stood when the details were handed over, which is what
      # decides later whether those details may be sent at all.
      "consent" => privacy_consent_choice
    }.compact_blank
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
