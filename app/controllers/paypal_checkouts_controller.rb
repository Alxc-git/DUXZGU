# The two calls the PayPal buttons make: one to open the order, one to capture it
# after the customer approves in the PayPal window.
#
# Both work from the orders held in the session, never from an amount sent by the
# browser, so the total charged is always the one the server computed.
class PaypalCheckoutsController < ApplicationController
  before_action :require_current_store!
  before_action :load_pending_orders!

  def create
    paypal_order_id = Payments::Paypal::CreateOrder.call(store: Current.store, orders: @orders)

    render json: { id: paypal_order_id }
  rescue Payments::Paypal::CreateOrder::Error => e
    Rails.logger.warn("[PayPal] creation refusee: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def capture
    result = Payments::Paypal::CaptureOrder.call(
      store: Current.store,
      paypal_order_id: params.require(:paypal_order_id),
      orders: @orders
    )

    session[:placed_order_ids] = result.orders.map(&:id)
    session.delete(:checkout_order_ids)
    current_cart.clear

    render json: { redirect_url: checkout_success_path }
  rescue Payments::Paypal::CaptureOrder::Error => e
    Rails.logger.error("[PayPal] capture echouee: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def load_pending_orders!
    @orders = Current.store.orders.where(id: session[:checkout_order_ids]).to_a

    return if @orders.any?

    render json: { error: t("checkout.expired") }, status: :gone
  end
end
