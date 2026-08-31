module Addresses
  # Komoot's Photon: OpenStreetMap data, built for search-as-you-type, no key and
  # no signup, which is what makes it the default.
  #
  # It has no country filter of its own, so more rows than the dropdown shows are
  # asked for and the ones the store cannot ship to are dropped here.
  class Photon < Provider
    ENDPOINT = "https://photon.komoot.io/api".freeze
    OVERFETCH = 4

    def search(query:, countries:, limit:, session_token: nil)
      body = get_json(uri(query, limit))
      return [] if body.nil?

      Array(body["features"])
        .filter_map { |feature| feature["properties"] }
        .select { |properties| deliverable?(properties, countries) }
        .filter_map { |properties| suggestion(properties) }
    end

    private

    def uri(query, limit)
      URI(ENDPOINT).tap do |uri|
        uri.query = URI.encode_www_form(q: query, limit: limit * OVERFETCH, lang: language)
      end
    end

    def deliverable?(properties, countries)
      countries.blank? || countries.include?(properties["countrycode"].to_s.upcase)
    end

    # A house result carries the street in `street`; a street result carries it in
    # `name` instead, so both are read before giving up on the row.
    def suggestion(properties)
      if properties["osm_key"] == "place" && properties["osm_value"] == "postcode"
        return Suggestion.postal(
          postal_code: properties["postcode"].presence || properties["name"],
          city: properties["city"].presence || properties["district"].presence || properties["county"],
          province: properties["state"],
          country: properties["countrycode"]
        )
      end

      Suggestion.build(
        house_number: properties["housenumber"],
        street: properties["street"].presence || properties["name"],
        city: properties["city"].presence || properties["district"].presence || properties["county"],
        province: properties["state"],
        # Photon's OSM postcode can describe a nearby street segment rather
        # than the selected civic address. Leave it for the customer until
        # Google Place Details is configured and can resolve the exact place.
        postal_code: nil,
        country: properties["countrycode"]
      )
    end
  end
end
