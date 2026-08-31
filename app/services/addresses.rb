# Address autocomplete for the checkout form.
#
# Google Places is preferred for exact address components. Geoapify remains a
# keyed alternative, while Photon keeps street suggestions working before a
# provider key is configured without being trusted for a civic postal code.
#
# Neither key ever reaches the browser: the dropdown talks to our own endpoint.
module Addresses
  module_function

  def provider
    return GooglePlaces.new(api_key: google_places_key) if google_places_key.present?
    return Geoapify.new(api_key: geoapify_key) if geoapify_key.present?

    Photon.new
  end

  def google_places_key
    ENV["GOOGLE_PLACES_API_KEY"].presence
  end

  def geoapify_key
    ENV["GEOAPIFY_API_KEY"].presence
  end
end
