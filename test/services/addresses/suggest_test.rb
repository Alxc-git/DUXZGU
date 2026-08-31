require "test_helper"

class Addresses::SuggestTest < ActiveSupport::TestCase
  # Stands in for a geocoder so the suite never leaves the machine.
  class FakeProvider
    attr_reader :calls

    def initialize(rows)
      @rows = rows
      @calls = []
    end

    def search(query:, countries:, limit:, session_token: nil)
      @calls << { query:, countries:, limit:, session_token: }
      @rows
    end
  end

  def suggestion(label:, line1: "789 Rue Sainte-Catherine Ouest")
    Addresses::Suggestion.new(label:, line1:, city: "Montreal", province: "Quebec",
      postal_code: "H2X 1Y6", country: "CA", place_id: nil)
  end

  def postal_suggestion
    Addresses::Suggestion.postal(postal_code: "J4J 2V5", city: "Longueuil", province: "Quebec", country: "CA")
  end

  test "returns the provider rows as hashes" do
    provider = FakeProvider.new([ suggestion(label: "789 Rue Sainte-Catherine Ouest, Montreal, Quebec H2X 1Y6") ])

    rows = Addresses::Suggest.call(query: "789 rue sainte", countries: [ "CA" ], provider:)

    assert_equal 1, rows.size
    assert_equal "H2X 1Y6", rows.first[:postal_code]
    assert_equal "CA", rows.first[:country]
  end

  test "does not call the provider for a query too short to narrow anything down" do
    provider = FakeProvider.new([])

    assert_empty Addresses::Suggest.call(query: "78", provider:)
    assert_empty provider.calls
  end

  test "drops duplicate rows and caps the list" do
    rows = Array.new(10) { |i| suggestion(label: "#{i % 2} Rue Test") }
    provider = FakeProvider.new(rows)

    assert_equal 2, Addresses::Suggest.call(query: "rue test", provider:).size
  end

  test "normalises the countries handed to the provider" do
    provider = FakeProvider.new([])

    Addresses::Suggest.call(query: "789 rue sainte", countries: [ " ca ", "", "us" ], provider:)

    assert_equal %w[CA US], provider.calls.first[:countries]
  end

  test "keeps only postal rows during a postal lookup" do
    provider = FakeProvider.new([
      suggestion(label: "789 Rue Sainte-Catherine Ouest"),
      postal_suggestion
    ])

    rows = Addresses::Suggest.call(query: "J4J", countries: [ "CA" ], mode: :postal, provider:)

    assert_equal [ "J4J 2V5" ], rows.pluck(:postal_code)
    assert_equal "", rows.first[:line1]
  end

  test "keeps only postal codes matching the typed prefix" do
    provider = FakeProvider.new([
      Addresses::Suggestion.postal(postal_code: "J4J 2V5", city: "Longueuil"),
      Addresses::Suggestion.postal(postal_code: "J4J 1X2", city: "Longueuil")
    ])

    rows = Addresses::Suggest.call(query: "j4j2", mode: :postal, provider:)

    assert_equal [ "J4J 2V5" ], rows.pluck(:postal_code)
  end

  test "does not replace a complete postal code with a nearby result" do
    provider = FakeProvider.new([ postal_suggestion ])

    rows = Addresses::Suggest.call(query: "J4J2X7", mode: :postal, provider:)

    assert_empty rows
  end
end
