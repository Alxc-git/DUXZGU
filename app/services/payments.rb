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
end
