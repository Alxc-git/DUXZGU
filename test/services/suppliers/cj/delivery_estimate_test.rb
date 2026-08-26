require "test_helper"

class Suppliers::Cj::DeliveryEstimateTest < ActiveSupport::TestCase
  # Stands in for the CJ client so the choice of carrier is tested, not the API.
  class FakeClient
    attr_reader :calls

    def initialize(options)
      @options = options
      @calls = []
    end

    def post(path, payload)
      @calls << [ path, payload ]
      raise Suppliers::Cj::Client::Error, @options if @options.is_a?(String)

      { "data" => @options }
    end
  end

  def estimate(options, **overrides)
    Suppliers::Cj::DeliveryEstimate.call(
      **{ client: FakeClient.new(options), country: "CA",
          postal_code: "H2X 1Y6", variant_ids: [ "vid-1" ] }.merge(overrides)
    )
  end

  test "prefers the fastest carrier among those close to the cheapest price" do
    result = estimate([
      { "logisticName" => "Lent", "logisticPrice" => 5.0, "logisticAging" => "7-15" },
      { "logisticName" => "Rapide", "logisticPrice" => 6.0, "logisticAging" => "4-7" }
    ])

    assert_equal "Rapide", result.carrier
    # Handling time is added on top of what the carrier quotes.
    assert_equal 6, result.min_days
    assert_equal 9, result.max_days
  end

  test "refuses a carrier priced far above the cheapest even when it is faster" do
    result = estimate([
      { "logisticName" => "Lent", "logisticPrice" => 5.0, "logisticAging" => "7-15" },
      { "logisticName" => "Express", "logisticPrice" => 40.0, "logisticAging" => "2-3" }
    ])

    assert_equal "Lent", result.carrier
  end

  test "reads a single figure as both ends of the window" do
    result = estimate([ { "logisticName" => "Fixe", "logisticPrice" => 5.0, "logisticAging" => "10" } ])

    assert_equal 12, result.min_days
    assert_equal 12, result.max_days
  end

  test "an option with no readable delay is skipped" do
    result = estimate([
      { "logisticName" => "Inconnu", "logisticPrice" => 1.0, "logisticAging" => "N/A" },
      { "logisticName" => "Lisible", "logisticPrice" => 9.0, "logisticAging" => "5-8" }
    ])

    assert_equal "Lisible", result.carrier
  end

  test "a CJ that hangs is abandoned instead of holding up the checkout" do
    slow = Class.new do
      def post(*)
        sleep 6
      end
    end.new

    started = Time.current
    result = Suppliers::Cj::DeliveryEstimate.call(
      client: slow, country: "CA", postal_code: "H2X 1Y6", variant_ids: [ "vid-1" ]
    )

    assert_nil result
    assert_operator Time.current - started, :<, 5.5, "le paiement ne doit pas attendre CJ"
  end

  test "a CJ outage returns nothing rather than raising into the checkout" do
    assert_nil estimate("CJ indisponible")
  end

  test "no address means no call to CJ" do
    client = FakeClient.new([])

    assert_nil Suppliers::Cj::DeliveryEstimate.call(
      client:, country: "", postal_code: "", variant_ids: [ "vid-1" ]
    )
    assert_empty client.calls
  end
end
