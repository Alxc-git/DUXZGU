require "test_helper"

class Addresses::GooglePlacesTest < ActiveSupport::TestCase
  def provider
    Addresses::GooglePlaces.new(api_key: "test-key")
  end

  test "returns Google place predictions with their place IDs" do
    requests = []
    google = provider
    google.define_singleton_method(:post_json) do |uri, payload, headers|
      requests << { uri:, payload:, headers: }
      {
        "suggestions" => [
          {
            "placePrediction" => {
              "placeId" => "ChIJ700RueGoyette",
              "text" => { "text" => "700 Rue Goyette, Longueuil, QC, Canada" }
            }
          }
        ]
      }
    end

    row = google.search(query: "700 rue go", countries: [ "CA" ], limit: 6, session_token: "session-123").first

    assert_equal "700 Rue Goyette, Longueuil, QC, Canada", row.label
    assert_equal "ChIJ700RueGoyette", row.place_id
    assert_empty row.line1
    assert_equal [ "ca" ], requests.first[:payload][:includedRegionCodes]
    assert_equal "session-123", requests.first[:payload][:sessionToken]
    assert_equal "test-key", requests.first[:headers]["X-Goog-Api-Key"]
  end

  test "builds the exact shipping fields from Google place details" do
    google = provider
    google.define_singleton_method(:get_json) do |_uri, _headers|
      {
        "id" => "ChIJ700RueGoyette",
        "formattedAddress" => "700 Rue Goyette, Longueuil, QC J4J 2X7, Canada",
        "addressComponents" => [
          { "longText" => "700", "shortText" => "700", "types" => [ "street_number" ] },
          { "longText" => "Rue Goyette", "shortText" => "Rue Goyette", "types" => [ "route" ] },
          { "longText" => "Longueuil", "shortText" => "Longueuil", "types" => [ "locality" ] },
          { "longText" => "Quebec", "shortText" => "QC", "types" => [ "administrative_area_level_1" ] },
          { "longText" => "J4J 2X7", "shortText" => "J4J 2X7", "types" => [ "postal_code" ] },
          { "longText" => "Canada", "shortText" => "CA", "types" => [ "country" ] }
        ]
      }
    end

    row = google.details(place_id: "ChIJ700RueGoyette", countries: [ "CA" ], session_token: "session-123")

    assert_equal "700 Rue Goyette", row.line1
    assert_equal "Longueuil", row.city
    assert_equal "Quebec", row.province
    assert_equal "J4J 2X7", row.postal_code
    assert_equal "CA", row.country
  end

  test "rejects malformed place IDs before calling Google" do
    google = provider
    google.define_singleton_method(:get_json) { flunk "Google should not be called" }

    assert_nil google.details(place_id: "../../secret", countries: [ "CA" ])
  end

  test "marks Google responses as uncached and attributed" do
    assert_not provider.cacheable?
    assert_equal "Google Maps", provider.attribution
  end
end
