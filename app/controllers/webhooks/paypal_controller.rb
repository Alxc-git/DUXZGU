module Webhooks
  # PayPal's own notifications. The browser already captures and confirms, so this
  # is the safety net: it catches a capture that completed while the customer had
  # already closed the tab, and it is the only path that hears about a refund.
  class PaypalController < ApplicationController
    skip_forgery_protection
    skip_before_action :set_current_store
    skip_after_action :track_visit

    def create
      event = JSON.parse(request.raw_post)

      unless signature_valid?(event)
        Rails.logger.warn("[PayPal] signature invalide event=#{event['id']}")
        return head :unauthorized
      end

      handle(event)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue StandardError => e
      # Anything other than 2xx makes PayPal retry, which is what should happen
      # when the failure is ours.
      Rails.logger.error("[PayPal] #{e.class}: #{e.message}")
      head :internal_server_error
    end

    private

    def handle(event)
      type = event["event_type"]
      Rails.logger.info("[PayPal] #{type} #{event['id']}")

      case type
      when "PAYMENT.CAPTURE.COMPLETED" then mark_paid(event)
      when "PAYMENT.CAPTURE.REFUNDED", "PAYMENT.CAPTURE.REVERSED" then mark_refunded(event)
      end
    end

    # `custom_id` carries the Rails order ids, set when the PayPal order was
    # opened, so the notification maps back without a second API call.
    def orders_for(event)
      resource = event["resource"].to_h
      ids = resource["custom_id"].to_s.split(",").map(&:to_i).reject(&:zero?)
      return Order.where(id: ids) if ids.any?

      paypal_order_id = resource.dig("supplementary_data", "related_ids", "order_id")
      return Order.none if paypal_order_id.blank?

      Order.where(paypal_order_id:)
    end

    def mark_paid(event)
      orders = orders_for(event).to_a
      return Rails.logger.warn("[PayPal] capture sans commande correspondante") if orders.empty?

      capture_id = event.dig("resource", "id")
      orders.each { |order| order.update!(paypal_capture_id: capture_id) if order.paypal_capture_id.blank? }

      Payments::MarkOrdersPaid.call(
        intent_id: nil, orders:, metadata: { "paypal_capture_id" => capture_id }
      )
    end

    def mark_refunded(event)
      orders_for(event).find_each do |order|
        next if order.refunded?

        order.update!(status: :refunded, refunded_at: Time.current)
      end
    end

    def signature_valid?(event)
      webhook_id = ENV["PAYPAL_WEBHOOK_ID"].presence
      headers = {
        auth_algo: request.get_header("HTTP_PAYPAL_AUTH_ALGO"),
        cert_url: request.get_header("HTTP_PAYPAL_CERT_URL"),
        transmission_id: request.get_header("HTTP_PAYPAL_TRANSMISSION_ID"),
        transmission_sig: request.get_header("HTTP_PAYPAL_TRANSMISSION_SIG"),
        transmission_time: request.get_header("HTTP_PAYPAL_TRANSMISSION_TIME")
      }

      return false if webhook_id.blank? || headers.values.any?(&:blank?)

      body = Payments::Paypal::Client.post(
        "/v1/notifications/verify-webhook-signature",
        headers.merge(webhook_id:, webhook_event: event)
      )
      body["verification_status"] == "SUCCESS"
    rescue Payments::Paypal::Client::Error => e
      Rails.logger.error("[PayPal] verification impossible: #{e.message}")
      false
    end
  end
end
