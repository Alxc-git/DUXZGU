module Webhooks
  class StripeController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      event = build_event
      Payments::HandleWebhook.call(event:)

      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue Stripe::SignatureVerificationError
      head :bad_request
    end

    private

    def build_event
      payload = request.body.read
      signature = request.env["HTTP_STRIPE_SIGNATURE"]
      secret = Rails.application.credentials.dig(:stripe, :webhook_secret).presence || ENV["STRIPE_WEBHOOK_SECRET"]

      raise Stripe::SignatureVerificationError.new("Missing webhook secret", signature) if secret.blank?

      Stripe::Webhook.construct_event(payload, signature, secret)
    end
  end
end
