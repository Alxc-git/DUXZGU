require "net/http"

module Addresses
  # Shared HTTP plumbing for the geocoders. A lookup that fails is never fatal:
  # the customer can always type the address by hand, so a provider returns nil
  # on any trouble and the dropdown simply stays closed.
  class Provider
    # The customer is mid-keystroke. A slow geocoder is worse than no geocoder.
    TIMEOUT = 3

    def search(query:, countries:, limit:, session_token: nil)
      raise NotImplementedError
    end

    def cacheable?
      true
    end

    def attribution
      nil
    end

    private

    def get_json(uri, headers = {})
      request = Net::HTTP::Get.new(uri, default_headers.merge(headers))
      request_json(uri, request)
    end

    def post_json(uri, payload, headers = {})
      request = Net::HTTP::Post.new(uri, default_headers.merge("Content-Type" => "application/json").merge(headers))
      request.body = JSON.generate(payload)
      request_json(uri, request)
    end

    def request_json(uri, request)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.request(request)
      end

      return JSON.parse(response.body.presence || "{}") if response.is_a?(Net::HTTPSuccess)

      Rails.logger.warn("[Addresses] #{self.class.name} returned HTTP #{response.code}")
      nil
    rescue Timeout::Error, SocketError, SystemCallError, IOError, JSON::ParserError => e
      Rails.logger.warn("[Addresses] #{self.class.name} unavailable: #{e.class} #{e.message}")
      nil
    end

    def default_headers
      { "User-Agent" => user_agent, "Accept" => "application/json" }
    end

    # Photon's public instance asks callers to identify themselves, so it can talk
    # to whoever is being noisy instead of just blocking the address bar.
    def user_agent
      "LUXTIME-checkout/1.0 (+https://#{ENV.fetch('APP_HOST', 'localhost')})"
    end

    def language
      I18n.locale.to_s.start_with?("fr") ? "fr" : "en"
    end
  end
end
