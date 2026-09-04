class PaymentsController < ApplicationController
  before_action :require_current_store!
  before_action :load_pending_orders!

  def new
    @flavor = current_cart.lines.first&.flavor || Flavor.find(params[:flavor].to_s)
    return unless Payments.configured?

    @client_secret = payment_intent.client_secret
  rescue Payments::CreatePaymentIntent::Error => e
    @payment_error = e.message
  end

  # Records an unpaid order so the flow is demonstrable end to end before any
  # Stripe key exists. It is barred outside development and test: in production a
  # misconfigured or expired key would otherwise turn this into a way to check out
  # for free.
  def create
    return redirect_to payment_path, alert: "Utilisez le formulaire de paiement." if Payments.configured?
    unless Rails.env.local?
      return redirect_to payment_path, alert: t("checkout.payment_unavailable",
        default: "Le paiement est momentanement indisponible. Merci de reessayer dans quelques minutes.")
    end

    complete_checkout
    redirect_to checkout_success_path
  end

  private

  def load_pending_orders!
    @orders = Current.store.orders
                     .where(id: session[:checkout_order_ids])
                     .includes(:product, variant: { image_attachment: :blob })
                     .to_a

    return if @orders.any?

    redirect_to cart_path, alert: t("checkout.expired")
  end

  # Reuses the intent already created for these orders, so a page reload does not
  # open a second one against the customer's card.
  def payment_intent
    existing = @orders.first.stripe_payment_intent_id
    reusable = retrieve_intent(existing) if existing.present?

    reusable || Payments::CreatePaymentIntent.call(
      store: Current.store, orders: @orders, details: checkout_details
    )
  end

  def retrieve_intent(id)
    intent = Stripe::PaymentIntent.retrieve(id, stripe_options)
    intent if intent.status.in?(%w[requires_payment_method requires_confirmation requires_action])
  rescue Stripe::StripeError
    nil
  end

  def checkout_details
    CheckoutForm.from_order(@orders.first)
  end

  def stripe_options
    Current.store.stripe_account_id.present? ? { stripe_account: Current.store.stripe_account_id } : {}
  end

  def complete_checkout
    session[:placed_order_ids] = @orders.map(&:id)
    session.delete(:checkout_order_ids)
    current_cart.clear
  end
end
