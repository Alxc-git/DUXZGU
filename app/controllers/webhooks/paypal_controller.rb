module Webhooks
  class PaypalController < ApplicationController
    skip_forgery_protection
    skip_before_action :set_current_store

    def create
      event = JSON.parse(request.raw_post)

      Rails.logger.info(
        "[PayPal Webhook] #{event['event_type']} #{event['id']}"
      )

      head :ok
    rescue JSON::ParserError
      head :bad_request
    end
  end
end