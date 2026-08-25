require "net/http"

module Payments
  module Paypal
    # Thin wrapper over the PayPal REST API: fetches an access token, caches it
    # for the life of the process, and issues JSON requests with it.
    #
    # The token is cached because PayPal issues one valid for nine hours and rate
    # limits the OAuth endpoint; asking for a new one per call is what gets an
    # integration throttled.
    class Client
      Error = Class.new(StandardError)

      LIVE_HOST = "https://api-m.paypal.com".freeze
      SANDBOX_HOST = "https://api-m.sandbox.paypal.com".freeze
      # Renewed a minute early so a request is never made with a token that
      # expires mid-flight.
      EXPIRY_MARGIN = 60

      def self.host
        Payments.paypal_live? ? LIVE_HOST : SANDBOX_HOST
      end

      def self.access_token
        @token = nil if @token_expires_at.nil? || Time.current >= @token_expires_at
        @token ||= fetch_token
      end

      def self.reset_token!
        @token = nil
        @token_expires_at = nil
      end

      def self.fetch_token
        raise Error, "PayPal n'est pas configure" unless Payments.paypal_configured?

        uri = URI("#{host}/v1/oauth2/token")
        request = Net::HTTP::Post.new(uri)
        request.basic_auth(Payments.paypal_client_id, Payments.paypal_secret)
        request["Accept"] = "application/json"
        request.set_form_data("grant_type" => "client_credentials")

        body = perform(uri, request)
        @token_expires_at = Time.current + (body["expires_in"].to_i - EXPIRY_MARGIN).seconds
        body.fetch("access_token")
      end
      private_class_method :fetch_token

      def self.post(path, payload, headers: {})
        call(Net::HTTP::Post, path, payload, headers)
      end

      def self.get(path)
        call(Net::HTTP::Get, path, nil, {})
      end

      def self.call(verb, path, payload, headers)
        uri = URI("#{host}#{path}")
        request = verb.new(uri)
        request["Authorization"] = "Bearer #{access_token}"
        request["Content-Type"] = "application/json"
        headers.each { |key, value| request[key] = value }
        request.body = payload.to_json if payload

        perform(uri, request)
      end
      private_class_method :call

      def self.perform(uri, request)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |http|
          http.request(request)
        end

        body = response.body.presence || "{}"
        parsed = JSON.parse(body)
        return parsed if response.is_a?(Net::HTTPSuccess)

        raise Error, describe(response, parsed)
      rescue JSON::ParserError
        raise Error, "Reponse PayPal illisible (HTTP #{response&.code})"
      rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, IOError => e
        raise Error, "PayPal injoignable: #{e.message}"
      end
      private_class_method :perform

      # PayPal reports the useful part in `details`, not in the top-level message.
      def self.describe(response, body)
        detail = Array(body["details"]).first
        reason = detail && [ detail["issue"], detail["description"] ].compact_blank.join(" - ")

        [ "PayPal HTTP #{response.code}", reason.presence || body["message"] ].compact_blank.join(": ")
      end
      private_class_method :describe
    end
  end
end
