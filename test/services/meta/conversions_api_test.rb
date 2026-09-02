require "test_helper"

module Meta
  class ConversionsApiTest < ActiveSupport::TestCase
    ENV_KEYS = {
      "META_PIXEL_ID" => "2010109929639061",
      "META_CONVERSIONS_API_TOKEN" => "SECRET-TOKEN-DO-NOT-LEAK",
      "META_GRAPH_API_VERSION" => "v23.0",
      "META_TEST_EVENT_CODE" => nil
    }.freeze

    # Captures what would have gone over the wire. Nothing in this suite reaches
    # Facebook: the one method that opens a socket is replaced.
    class FakeResponse
      def initialize(code, body) = (@code, @body = code.to_s, body)
      attr_reader :code, :body
      def is_a?(klass) = klass == Net::HTTPSuccess ? @code.start_with?("2") : super
    end

    def build(**overrides)
      ConversionsApi.new(
        **{ event_name: "Purchase", event_id: "purchase_stripe_pi_123",
            event_time: 1_764_000_000, event_source_url: "https://example.com/commande",
            user_data: { em: [ "abc" ], client_ip_address: "24.48.0.1" },
            custom_data: { value: 49.0, currency: "CAD" } }.merge(overrides)
      )
    end

    # Returns the parsed request body instead of sending it.
    def capture(service, response: FakeResponse.new(200, { events_received: 1 }.to_json))
      sent = nil
      service.define_singleton_method(:post) do
        sent = JSON.parse(payload.to_json)
        response
      end
      result = service.call
      [ sent, result ]
    end

    test "posts the Meta event structure" do
      with_env(ENV_KEYS) do
        body, result = capture(build)
        event = body["data"].first

        assert_equal 1, body["data"].size
        assert_equal "Purchase", event["event_name"]
        assert_equal "purchase_stripe_pi_123", event["event_id"]
        assert_equal 1_764_000_000, event["event_time"]
        assert_equal "website", event["action_source"]
        assert_equal "https://example.com/commande", event["event_source_url"]
        assert_equal({ "em" => [ "abc" ], "client_ip_address" => "24.48.0.1" }, event["user_data"])
        assert_equal 49.0, event["custom_data"]["value"]
        assert_equal 1, result.events_received
      end
    end

    test "sends the token in the body and never in the url" do
      with_env(ENV_KEYS) do
        body, = capture(build)

        assert_equal "SECRET-TOKEN-DO-NOT-LEAK", body["access_token"]
        assert_not_includes Meta.events_endpoint, "SECRET-TOKEN-DO-NOT-LEAK"
        assert_not_includes Meta.events_endpoint, "access_token"
      end
    end

    test "targets the configured dataset and graph version" do
      with_env(ENV_KEYS) do
        assert_equal "https://graph.facebook.com/v23.0/2010109929639061/events", Meta.events_endpoint
      end
    end

    test "adds the test event code only when one is configured" do
      with_env(ENV_KEYS) do
        body, = capture(build)
        assert_not body.key?("test_event_code")
      end

      with_env(ENV_KEYS.merge("META_TEST_EVENT_CODE" => "TEST12345")) do
        body, = capture(build)
        assert_equal "TEST12345", body["test_event_code"]
      end
    end

    test "refuses to send anything without a token" do
      with_env(ENV_KEYS.merge("META_CONVERSIONS_API_TOKEN" => nil)) do
        assert_raises(ConversionsApi::Error) { build.call }
      end
    end

    test "raises with the status and no secret when Meta rejects the event" do
      with_env(ENV_KEYS) do
        failure = FakeResponse.new(400, { error: { message: "Invalid parameter", code: 100 } }.to_json)
        service = build

        error = assert_raises(ConversionsApi::Error) { capture(service, response: failure) }

        assert_includes error.message, "status=400"
        assert_includes error.message, "Invalid parameter"
        assert_not_includes error.message, "SECRET-TOKEN-DO-NOT-LEAK"
      end
    end
  end
end
