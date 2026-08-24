require "net/http"

module Suppliers
  module Cj
    class Client < Suppliers::BaseClient
      class Error < StandardError; end
      # Raised when CJ rejects the access token; triggers a single refresh and retry.
      class AuthError < Error; end

      DEFAULT_BASE_URL = "https://developers.cjdropshipping.com/api2.0/v1".freeze
      SUCCESS_CODE = 200
      # CJ signals token problems through this family of business codes.
      AUTH_CODES = [ 1600000, 1600100, 1600200, 1600300 ].freeze

      def create_order(order)
        CreateOrder.call(client: self, order:)
      end

      def tracking(order)
        response = get("/shopping/order/getOrderDetail", { orderId: order.supplier_order_id })
        data = response["data"] || {}
        number = data["trackNumber"].presence

        {
          tracking_number: number,
          tracking_url: data["trackingUrl"].presence || default_tracking_url(number),
          tracking_provider: data["trackingProvider"],
          supplier_status: data["orderStatus"]
        }
      end

      def post(path, payload)
        request(:post, path, payload:)
      end

      def get(path, params = {})
        request(:get, path, params:)
      end

      # `authenticated: false` is used by the token endpoints themselves.
      def request(method, path, payload: nil, params: nil, authenticated: true, retry_on_auth: true)
        response = perform_request(method, path, payload:, params:, authenticated:)
        parse_response(response)
      rescue AuthError => e
        raise e unless authenticated && retry_on_auth

        Rails.logger.warn("[CJ] access token rejected, refreshing once: #{e.message}")
        AccessToken.reset!(store)
        request(method, path, payload:, params:, authenticated:, retry_on_auth: false)
      end

      def access_token
        AccessToken.call(client: self, store:)
      end

      def base_url
        store.supplier_settings["base_url"].presence || DEFAULT_BASE_URL
      end

      def api_key
        store.supplier_settings["api_key"].presence ||
          Rails.application.credentials.dig(:cj, :api_key).presence ||
          ENV["CJ_API_KEY"]
      end

      def email
        store.supplier_settings["email"].presence ||
          Rails.application.credentials.dig(:cj, :email).presence ||
          ENV["CJ_EMAIL"]
      end

      private

      def perform_request(method, path, payload:, params:, authenticated:)
        uri = build_uri(path, params)
        http_request = build_http_request(method, uri, payload)
        http_request["Content-Type"] = "application/json"
        http_request["CJ-Access-Token"] = access_token if authenticated

        perform(uri, http_request)
      end

      def build_uri(path, params)
        uri = URI.join("#{base_url}/", path.delete_prefix("/"))
        uri.query = URI.encode_www_form(params.compact) if params.present?
        uri
      end

      def build_http_request(method, uri, payload)
        case method
        when :post
          Net::HTTP::Post.new(uri).tap { |req| req.body = payload.to_json }
        when :get
          Net::HTTP::Get.new(uri)
        else
          raise Error, "Unsupported HTTP method #{method}"
        end
      end

      def perform(uri, http_request)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10, read_timeout: 30) do |http|
          http.request(http_request)
        end
      rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, IOError => e
        Rails.logger.error("[CJ] request failed: #{e.class}: #{e.message}")
        raise Error, e.message
      end

      def parse_response(response)
        body = JSON.parse(response.body.presence || "{}")
        return body if success?(response, body)

        message = body["message"].presence || "CJ API returned HTTP #{response.code}"
        Rails.logger.error("[CJ] #{message} (code=#{body['code']})")
        raise auth_failure?(response, body) ? AuthError.new(message) : Error.new(message)
      rescue JSON::ParserError => e
        Rails.logger.error("[CJ] invalid JSON: #{e.message}")
        raise Error, "Invalid CJ response"
      end

      def success?(response, body)
        return false unless response.is_a?(Net::HTTPSuccess)
        return false if body["result"] == false
        return false if body.key?("code") && body["code"].to_i != SUCCESS_CODE

        true
      end

      def auth_failure?(response, body)
        return true if response.code.to_i == 401
        return true if AUTH_CODES.include?(body["code"].to_i)

        body["message"].to_s.match?(/token/i)
      end

      def default_tracking_url(number)
        return if number.blank?

        "https://www.17track.net/en/track?nums=#{number}"
      end
    end
  end
end
