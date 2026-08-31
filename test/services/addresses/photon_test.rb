require "test_helper"

class Addresses::PhotonTest < ActiveSupport::TestCase
  def feature(properties)
    { "properties" => properties }
  end

  def photon_returning(features)
    Addresses::Photon.new.tap do |provider|
      provider.define_singleton_method(:get_json) { |_uri| { "features" => features } }
    end
  end

  test "builds a suggestion from a house result" do
    provider = photon_returning([
      feature("housenumber" => "789", "street" => "Rue Sainte-Catherine Ouest", "city" => "Montreal",
        "state" => "Quebec", "postcode" => "H2X 1Y6", "countrycode" => "CA")
    ])

    row = provider.search(query: "789 rue sainte", countries: [ "CA" ], limit: 6).first

    assert_equal "789 Rue Sainte-Catherine Ouest", row.line1
    assert_equal "Montreal", row.city
    assert_empty row.postal_code
    assert_equal "789 Rue Sainte-Catherine Ouest, Montreal, Quebec", row.label
  end

  test "falls back to the feature name when a street result carries no street" do
    provider = photon_returning([
      feature("name" => "Rue Sainte-Catherine Ouest", "city" => "Montreal", "countrycode" => "CA")
    ])

    assert_equal "Rue Sainte-Catherine Ouest", provider.search(query: "rue sainte", countries: [], limit: 6).first.line1
  end

  test "drops results outside the countries the store ships to" do
    provider = photon_returning([
      feature("housenumber" => "789", "street" => "Main Street", "city" => "Boston", "countrycode" => "US")
    ])

    assert_empty provider.search(query: "789 main", countries: [ "CA" ], limit: 6)
  end

  test "builds a postal suggestion without treating the code as a street" do
    provider = photon_returning([
      feature("osm_key" => "place", "osm_value" => "postcode", "name" => "J4J 2V5",
        "city" => "Longueuil", "state" => "Quebec", "countrycode" => "CA")
    ])

    row = provider.search(query: "J4J 2", countries: [ "CA" ], limit: 6).first

    assert_equal "J4J 2V5", row.postal_code
    assert_equal "", row.line1
    assert_equal "J4J 2V5, Longueuil, Quebec", row.label
  end

  test "returns nothing when the geocoder is unreachable" do
    provider = Addresses::Photon.new
    provider.define_singleton_method(:get_json) { |_uri| nil }

    assert_empty provider.search(query: "789 rue sainte", countries: [ "CA" ], limit: 6)
  end
end
