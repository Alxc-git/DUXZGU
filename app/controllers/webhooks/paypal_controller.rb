require "net/http"
require "uri"
require "json"

module Webhooks
  class PaypalController < ApplicationController
    skip_forgery_protection
    skip_before_action :set_current_store

    def create
      event = JSON.parse(request.raw_post)

      unless paypal_signature_valid?(event)
        Rails.logger.warn(
          "[PayPal Webhook] INVALID SIGNATURE event=#{event['id']}"
        )

        return head :unauthorized
      end

      Rails.logger.info(
        "[PayPal Webhook] VERIFIED #{event['event_type']} #{event['id']}"
      )

      case event["event_type"]
      when "PAYMENT.CAPTURE.COMPLETED"
        Rails.logger.info("[PayPal] Payment completed")

      when "PAYMENT.CAPTURE.DECLINED"
        Rails.logger.warn("[PayPal] Payment declined")

      when "PAYMENT.CAPTURE.PENDING"
        Rails.logger.info("[PayPal] Payment pending")

      when "PAYMENT.CAPTURE.REFUNDED"
        Rails.logger.info("[PayPal] Payment refunded")

      when "PAYMENT.CAPTURE.REVERSED"
        Rails.logger.warn("[PayPal] Payment reversed")

      when "CHECKOUT.ORDER.APPROVED"
        Rails.logger.info("[PayPal] Order approved")
      end

      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue StandardError => e
      Rails.logger.error(
        "[PayPal Webhook] #{e.class}: #{e.message}"
      )

      head :internal_server_error
    end

    private

    def paypal_signature_valid?(event)
      webhook_id = ENV["PAYPAL_WEBHOOK_ID"]

      transmission_id   = request.get_header("HTTP_PAYPAL_TRANSMISSION_ID")
      transmission_time = request.get_header("HTTP_PAYPAL_TRANSMISSION_TIME")
      transmission_sig  = request.get_header("HTTP_PAYPAL_TRANSMISSION_SIG")
      cert_url          = request.get_header("HTTP_PAYPAL_CERT_URL")
      auth_algo         = request.get_header("HTTP_PAYPAL_AUTH_ALGO")

      required_values = [
        webhook_id,
        transmission_id,
        transmission_time,
        transmission_sig,
        cert_url,
        auth_algo
      ]

      return false if required_values.any?(&:blank?)

      uri = URI("#{paypal_api_base}/v1/notifications/verify-webhook-signature")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      verification_request = Net::HTTP::Post.new(uri)
      verification_request["Authorization"] = "Bearer #{paypal_access_token}"
      verification_request["Content-Type"] = "application/json"

      verification_request.body = {
        auth_algo: auth_algo,
        cert_url: cert_url,
        transmission_id: transmission_id,
        transmission_sig: transmission_sig,
        transmission_time: transmission_time,
        webhook_id: webhook_id,
        webhook_event: event
      }.to_json

      response = http.request(verification_request)

      return false unless response.is_a?(Net::HTTPSuccess)

      result = JSON.parse(response.body)

      result["verification_status"] == "SUCCESS"
    end

    def paypal_access_token
      uri = URI("#{paypal_api_base}/v1/oauth2/token")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      token_request = Net::HTTP::Post.new(uri)
      token_request.basic_auth(
        ENV.fetch("PAYPAL_CLIENT_ID"),
        ENV.fetch("PAYPAL_CLIENT_SECRET")
      )

      token_request["Accept"] = "application/json"
      token_request["Accept-Language"] = "en_US"
      token_request.set_form_data(
        "grant_type" => "client_credentials"
      )

      response = http.request(token_request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "PayPal OAuth failed: HTTP #{response.code}"
      end

      JSON.parse(response.body).fetch("access_token")
    end

    def paypal_api_base
      if ENV.fetch("PAYPAL_ENV", "sandbox") == "live"
        "https://api-m.paypal.com"
      else
        "https://api-m.sandbox.paypal.com"
      end
    end
  end
end