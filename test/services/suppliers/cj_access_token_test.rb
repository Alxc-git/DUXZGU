require "test_helper"

module Suppliers
  module Cj
    class AccessTokenTest < ActiveSupport::TestCase
      setup do
        @store = stores(:demo)
        @store.update!(supplier_settings: { "api_key" => "cj-user@api@secret" })
      end

      test "authenticates once and caches the token on the store" do
        client = stub_client
        calls = record_calls(client)

        assert_equal "token-1", AccessToken.call(client:, store: @store)
        assert_equal "token-1", AccessToken.call(client:, store: @store.reload)

        assert_equal 1, calls.size
        assert_equal "/authentication/getAccessToken", calls.first[:path]
        assert_equal({ apiKey: "cj-user@api@secret" }, calls.first[:payload])
        assert_equal "token-1", @store.reload.supplier_settings["access_token"]
      end

      test "refreshes with the refresh token once the access token lapses" do
        @store.update!(supplier_settings: @store.supplier_settings.merge(
          "access_token" => "stale",
          "access_token_expires_at" => 1.minute.from_now.to_s,
          "refresh_token" => "refresh-1",
          "refresh_token_expires_at" => 100.days.from_now.to_s
        ))
        client = stub_client
        calls = record_calls(client)

        assert_equal "token-1", AccessToken.call(client:, store: @store)
        assert_equal "/authentication/refreshAccessToken", calls.first[:path]
        assert_equal({ refreshToken: "refresh-1" }, calls.first[:payload])
      end

      test "falls back to a full authentication when the refresh token is rejected" do
        @store.update!(supplier_settings: @store.supplier_settings.merge(
          "refresh_token" => "expired", "refresh_token_expires_at" => 100.days.from_now.to_s
        ))
        client = stub_client(fail_refresh: true)
        calls = record_calls(client)

        assert_equal "token-1", AccessToken.call(client:, store: @store)
        assert_equal %w[/authentication/refreshAccessToken /authentication/getAccessToken], calls.map { |call| call[:path] }
      end

      test "reuses a still-valid cached token without calling CJ" do
        @store.update!(supplier_settings: @store.supplier_settings.merge(
          "access_token" => "cached", "access_token_expires_at" => 10.days.from_now.to_s
        ))
        client = stub_client
        calls = record_calls(client)

        assert_equal "cached", AccessToken.call(client:, store: @store)
        assert_empty calls
      end

      test "raises when no API key is configured" do
        @store.update!(supplier_settings: {})
        client = stub_client(api_key: nil)

        assert_raises(Client::Error) { AccessToken.call(client:, store: @store) }
      end

      private

      def stub_client(api_key: "cj-user@api@secret", fail_refresh: false)
        client = Object.new
        client.define_singleton_method(:api_key) { api_key }
        client.define_singleton_method(:request) do |_method, path, payload:, authenticated:|
          raise Client::Error, "refresh token expired" if fail_refresh && path.include?("refresh")

          {
            "data" => {
              "accessToken" => "token-1",
              "accessTokenExpiryDate" => 15.days.from_now.to_s,
              "refreshToken" => "refresh-2",
              "refreshTokenExpiryDate" => 180.days.from_now.to_s
            }
          }
        end
        client
      end

      def record_calls(client)
        calls = []
        original = client.method(:request)
        client.define_singleton_method(:request) do |method, path, payload:, authenticated:|
          calls << { path:, payload: }
          original.call(method, path, payload:, authenticated:)
        end
        calls
      end
    end
  end
end
