module Addresses
  # Google Places (New) is used server-side so the API key never reaches the
  # browser. Autocomplete returns only labels and place IDs; address components
  # are fetched after a customer selects one row.
  class GooglePlaces < Provider
    AUTOCOMPLETE_ENDPOINT = URI("https://places.googleapis.com/v1/places:autocomplete")
    DETAILS_ENDPOINT = "https://places.googleapis.com/v1/places".freeze
    PLACE_ID_PATTERN = /\A[A-Za-z0-9_-]{10,255}\z/

    def initialize(api_key:)
      @api_key = api_key
    end

    def search(query:, countries:, limit:, session_token: nil)
      body = post_json(AUTOCOMPLETE_ENDPOINT, autocomplete_payload(query, countries, session_token), autocomplete_headers)
      return [] if body.nil?

      Array(body["suggestions"])
        .filter_map { |row| prediction(row["placePrediction"]) }
        .first(limit)
    end

    def details(place_id:, countries:, session_token: nil)
      return unless place_id.to_s.match?(PLACE_ID_PATTERN)

      body = get_json(details_uri(place_id, countries, session_token), details_headers)
      return if body.nil?

      detailed_suggestion(body)
    end

    # Google Places content may not be cached, and predictions displayed without
    # a map must carry visible Google Maps attribution.
    def cacheable?
      false
    end

    def attribution
      "Google Maps"
    end

    private

    attr_reader :api_key

    def autocomplete_payload(query, countries, session_token)
      {
        input: query,
        includedRegionCodes: countries.map(&:downcase),
        languageCode: language,
        sessionToken: session_token.presence
      }.compact
    end

    def autocomplete_headers
      {
        "X-Goog-Api-Key" => api_key,
        "X-Goog-FieldMask" => "suggestions.placePrediction.placeId,suggestions.placePrediction.text.text"
      }
    end

    def prediction(row)
      return if row.blank?

      Suggestion.prediction(label: row.dig("text", "text"), place_id: row["placeId"])
    end

    def details_uri(place_id, countries, session_token)
      params = { languageCode: language, sessionToken: session_token.presence }
      params[:regionCode] = countries.first if countries.one?

      URI("#{DETAILS_ENDPOINT}/#{place_id}").tap do |uri|
        uri.query = URI.encode_www_form(params.compact)
      end
    end

    def details_headers
      {
        "X-Goog-Api-Key" => api_key,
        "X-Goog-FieldMask" => "id,formattedAddress,addressComponents"
      }
    end

    def detailed_suggestion(body)
      components = Array(body["addressComponents"])
      street_number = component(components, "street_number")
      street = component(components, "route")
      city = component(components, "locality") ||
        component(components, "postal_town") ||
        component(components, "sublocality_level_1") ||
        component(components, "administrative_area_level_3")
      province = component(components, "administrative_area_level_1")
      postal_code = component(components, "postal_code")
      country = component(components, "country", short: true)

      if street.present?
        Suggestion.build(house_number: street_number, street:, city:, province:, postal_code:, country:)
      elsif postal_code.present?
        Suggestion.postal(postal_code:, city:, province:, country:)
      end
    end

    def component(components, type, short: false)
      row = components.find { |candidate| type.in?(Array(candidate["types"])) }
      row&.fetch(short ? "shortText" : "longText", nil)
    end
  end
end
