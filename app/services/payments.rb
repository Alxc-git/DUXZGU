# Payment configuration shared by the checkout pages and the Stripe services.
#
# The storefront must stay usable before any key exists, so `configured?` is what
# every caller branches on: with keys the customer pays through Stripe, without
# them the order is still recorded and the payment step says so plainly.
module Payments
  module_function

  def publishable_key
    Rails.application.credentials.dig(:stripe, :publishable_key).presence ||
      ENV["STRIPE_PUBLISHABLE_KEY"].presence
  end

  def secret_key
    Stripe.api_key.presence
  end

  def configured?
    secret_key.present? && publishable_key.present?
  end

  # ------------------------------------------------------------------- PayPal
  #
  # PayPal is wired directly rather than through Stripe, which does not offer it
  # for every merchant country. It is optional: without credentials the button
  # simply does not render and the card form is unaffected.

  def paypal_client_id
    ENV["PAYPAL_CLIENT_ID"].presence
  end

  def paypal_secret
    ENV["PAYPAL_CLIENT_SECRET"].presence
  end

  def paypal_live?
    ENV.fetch("PAYPAL_ENV", "sandbox").casecmp?("live")
  end

  def paypal_configured?
    paypal_client_id.present? && paypal_secret.present?
  end
end
