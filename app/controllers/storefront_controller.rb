class StorefrontController < ApplicationController
  before_action :require_current_store!

  def home
    # No redirect when the store has no product: root is the redirect target,
    # so bouncing here would loop. The template renders an empty state instead.
    @product = current_product
  end

  def show
    @product = Current.store.products.active.includes(:variants).find_by!(slug: params[:slug])
    @variant = @product.variant_for(params[:couleur]) || @product.default_variant

    track_meta_event("ViewContent", Meta::Content.for_product(@product, variant: @variant))
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Produit indisponible"
  end

  # The ids come from the session, set when the order was placed, so a customer
  # can only ever see their own confirmation.
  def success
    confirm_stripe_return if params[:payment_intent].present?

    @orders = Current.store.orders
                     .where(id: session[:placed_order_ids])
                     .includes(:product, variant: { image_attachment: :blob })
                     .to_a
    # `paid_at` rather than the status: an order that already moved on to
    # fulfillment — or whose supplier handoff failed — was still paid for.
    @awaiting_payment = @orders.any? { |order| order.paid_at.blank? }
  end

  def cancel; end

  private

  # Stripe sends the customer back here after the Payment Element confirms. The
  # webhook is still the authority, but reading the intent now means the page can
  # show a paid order immediately instead of waiting for the event to land.
  def confirm_stripe_return
    intent = Stripe::PaymentIntent.retrieve(params[:payment_intent], stripe_options)
    return unless intent.status == "succeeded"

    Payments::MarkOrdersPaid.call(intent_id: intent.id, metadata: intent.metadata)
    session[:placed_order_ids] = session.delete(:checkout_order_ids) if session[:checkout_order_ids].present?
    current_cart.clear
  rescue Stripe::StripeError => e
    Rails.logger.warn("[Checkout] could not read the payment intent: #{e.message}")
  end

  def stripe_options
    Current.store.stripe_account_id.present? ? { stripe_account: Current.store.stripe_account_id } : {}
  end
end
