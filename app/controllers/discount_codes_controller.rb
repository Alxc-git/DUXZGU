class DiscountCodesController < ApplicationController
  before_action :require_current_store!

  MESSAGES = {
    ok: "cart.promo.applied",
    unknown: "cart.promo.unknown",
    inactive: "cart.promo.unknown",
    expired: "cart.promo.expired",
    exhausted: "cart.promo.exhausted",
    minimum: "cart.promo.minimum"
  }.freeze

  def create
    outcome = current_cart.apply_discount_code(params[:code])
    key = MESSAGES.fetch(outcome, MESSAGES[:unknown])

    if outcome == :ok
      redirect_back fallback_location: cart_path,
        notice: t(key, code: current_cart.discount_code.code, default: "Promo code applied.")
    else
      redirect_back fallback_location: cart_path, alert: alert_for(key)
    end
  end

  def destroy
    current_cart.remove_discount_code
    redirect_back fallback_location: cart_path, notice: t("cart.promo.removed", default: "Promo code removed.")
  end

  private

  # The minimum message has to name the amount, so it cannot share the simple path.
  def alert_for(key)
    return t(key, default: "That promo code is not valid.") unless key == MESSAGES[:minimum]

    code = DiscountCode.lookup(Current.store, params[:code])
    t(key,
      amount: MoneyFormatter.format(code&.minimum_cents.to_i, current_cart.currency),
      default: "This code needs a bigger order.")
  end
end
