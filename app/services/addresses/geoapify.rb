module Addresses
  # Geoapify's autocomplete endpoint. It filters by country server side and comes
  # with a published quota, which is why a key wins over Photon when one is set.
  class Geoapify < Provider
    ENDPOINT = "https://api.geoapify.com/v1/geocode/autocomplete".freeze

    def initialize(api_key:)
      @api_key = api_key
    end

    def search(query:, countries:, limit:, session_token: nil)
      body = get_json(uri(query, countries, limit))
      return [] if body.nil?

      Array(body["results"]).filter_map { |result| suggestion(result) }
    end

    private

    attr_reader :api_key

    def uri(query, countries, limit)
      params = { text: query, limit:, lang: language, format: "json", apiKey: api_key }
      params[:filter] = "countrycode:#{countries.map(&:downcase).join(',')}" if countries.present?

      URI(ENDPOINT).tap { |uri| uri.query = URI.encode_www_form(params) }
    end

    def suggestion(result)
      if result["result_type"] == "postcode" && result["street"].blank? && result["housenumber"].blank?
        return Suggestion.postal(
          postal_code: result["postcode"],
          city: result["city"].presence || result["county"],
          province: result["state"],
          country: result["country_code"]
        )
      end

      Suggestion.build(
        house_number: result["housenumber"],
        street: result["street"].presence || result["name"],
        city: result["city"].presence || result["county"],
        province: result["state"],
        postal_code: result["postcode"],
        country: result["country_code"]
      )
    end
  end
end
