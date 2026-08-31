require "test_helper"

class AddressSuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  # Stands in for a geocoder so the suite never leaves the machine.
  class FakeProvider
    attr_reader :calls, :detail_calls

    def initialize(rows = [], details: nil, attribution: nil)
      @rows = rows
      @details = details
      @attribution = attribution
      @calls = []
      @detail_calls = []
    end

    def search(query:, countries:, limit:, session_token: nil)
      @calls << { query:, countries:, limit:, session_token: }
      @rows
    end

    def details(place_id:, countries:, session_token: nil)
      @detail_calls << { place_id:, countries:, session_token: }
      @details
    end

    attr_reader :attribution
  end

  def montreal
    Addresses::Suggestion.new(label: "789 Rue Sainte-Catherine Ouest, Montreal, Quebec H2X 1Y6",
      line1: "789 Rue Sainte-Catherine Ouest", city: "Montreal", province: "Quebec",
      postal_code: "H2X 1Y6", country: "CA", place_id: nil)
  end

  def longueuil_postal
    Addresses::Suggestion.postal(postal_code: "J4J 2V5", city: "Longueuil", province: "Quebec", country: "CA")
  end

  # Minitest 6 dropped its mock library, and the seam we need is a single module
  # method, so it is swapped by hand and put back.
  def with_provider(provider)
    original = Addresses.method(:provider)
    Addresses.define_singleton_method(:provider) { provider }
    yield
  ensure
    Addresses.define_singleton_method(:provider, original)
  end

  test "suggests addresses for what the customer has typed so far" do
    with_provider(FakeProvider.new([ montreal ])) do
      get address_suggestions_path, params: { q: "789 rue sainte" }
    end

    assert_response :success
    row = JSON.parse(response.body)["suggestions"].first
    assert_equal "789 Rue Sainte-Catherine Ouest", row["line1"]
    assert_equal "H2X 1Y6", row["postal_code"]
  end

  test "narrows the search to the country picked in the form" do
    provider = FakeProvider.new

    with_provider(provider) { get address_suggestions_path, params: { q: "789 rue", country: "ca" } }

    assert_equal [ "CA" ], provider.calls.first[:countries]
  end

  test "uses the city and partial postal code to narrow an address lookup" do
    provider = FakeProvider.new

    with_provider(provider) do
      get address_suggestions_path,
        params: { q: "700 rue go", city: "Longueuil", postal_code: "J4J 2V5", mode: "address" }
    end

    assert_equal "700 rue go Longueuil J4J", provider.calls.first[:query]
  end

  test "returns postal code suggestions separately from street addresses" do
    with_provider(FakeProvider.new([ longueuil_postal ])) do
      get address_suggestions_path, params: { q: "J4J 2", country: "CA", mode: "postal" }
    end

    row = JSON.parse(response.body)["suggestions"].first
    assert_equal "J4J 2V5", row["postal_code"]
    assert_equal "", row["line1"]
  end

  test "returns Google attribution and resolves a selected place" do
    prediction = Addresses::Suggestion.prediction(
      label: "700 Rue Goyette, Longueuil, QC, Canada", place_id: "ChIJ700RueGoyette"
    )
    details = Addresses::Suggestion.build(
      house_number: "700", street: "Rue Goyette", city: "Longueuil", province: "Quebec",
      postal_code: "J4J 2X7", country: "CA"
    )
    provider = FakeProvider.new([ prediction ], details:, attribution: "Google Maps")

    with_provider(provider) do
      get address_suggestions_path,
        params: { q: "700 rue go", country: "CA", session_token: "session-123" }
      suggestions_payload = JSON.parse(response.body)

      assert_equal "Google Maps", suggestions_payload["attribution"]
      assert_equal "ChIJ700RueGoyette", suggestions_payload["suggestions"].first["place_id"]

      get address_details_path,
        params: { place_id: "ChIJ700RueGoyette", country: "CA", session_token: "session-123" }
    end

    assert_response :success
    assert_equal "J4J 2X7", JSON.parse(response.body).dig("suggestion", "postal_code")
    assert_equal "session-123", provider.calls.first[:session_token]
    assert_equal "session-123", provider.detail_calls.first[:session_token]
  end

  test "does not suggest a nearby code for a complete postal code" do
    with_provider(FakeProvider.new([ longueuil_postal ])) do
      get address_suggestions_path, params: { q: "J4J2X7", country: "CA", mode: "postal" }
    end

    assert_response :success
    assert_empty JSON.parse(response.body)["suggestions"]
  end

  test "ignores a country the store does not ship to" do
    provider = FakeProvider.new

    with_provider(provider) { get address_suggestions_path, params: { q: "789 rue", country: "FR" } }

    assert_equal stores(:demo).shipping_countries, provider.calls.first[:countries]
  end

  test "returns nothing for a query too short to narrow anything down" do
    provider = FakeProvider.new

    with_provider(provider) { get address_suggestions_path, params: { q: "78" } }

    assert_response :success
    assert_empty JSON.parse(response.body)["suggestions"]
    assert_empty provider.calls
  end

  test "rate limits noisy sessions" do
    with_provider(FakeProvider.new) do
      AddressSuggestionsController::MAX_PER_WINDOW.times do
        get address_suggestions_path, params: { q: "789 rue sainte" }
        assert_response :success
      end

      get address_suggestions_path, params: { q: "789 rue sainte" }
    end

    assert_response :too_many_requests
  end
end
