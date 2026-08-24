module Suppliers
  module Cj
    # Owns the CJ access token lifecycle. Tokens live 15 days and refresh tokens
    # 180 days, and the token endpoint is rate limited to one call per second, so
    # the token is cached on the store and only renewed when it is about to lapse.
    class AccessToken < ApplicationService
      # Generous margin: CJ returns expiry dates without a reliable timezone.
      REFRESH_MARGIN = 1.hour

      def self.reset!(store)
        store.with_lock do
          store.update!(supplier_settings: store.supplier_settings.except("access_token", "access_token_expires_at"))
        end
      end

      def initialize(client:, store:)
        @client = client
        @store = store
      end

      def call
        return static_token if static_token.present?

        cached = cached_token
        return cached if cached.present?

        store.with_lock do
          # Another process may have renewed the token while we waited for the lock.
          fresh = cached_token
          next fresh if fresh.present?

          persist(fetch_token)
        end
      end

      private

      attr_reader :client, :store

      # Escape hatch for accounts pasting a token by hand instead of using an API key.
      def static_token
        return if client.api_key.present?

        @static_token ||= store.supplier_settings["access_token"].presence ||
          Rails.application.credentials.dig(:cj, :access_token).presence ||
          ENV["CJ_ACCESS_TOKEN"]
      end

      def cached_token
        token = store.supplier_settings["access_token"].presence
        return if token.blank?
        return if expired?(store.supplier_settings["access_token_expires_at"])

        token
      end

      def fetch_token
        refreshed = refresh if refreshable?
        refreshed.presence || authenticate
      end

      def refreshable?
        store.supplier_settings["refresh_token"].present? &&
          !expired?(store.supplier_settings["refresh_token_expires_at"])
      end

      def refresh
        client.request(
          :post,
          "/authentication/refreshAccessToken",
          payload: { refreshToken: store.supplier_settings["refresh_token"] },
          authenticated: false
        )["data"]
      rescue Client::Error => e
        Rails.logger.warn("[CJ] refresh failed, re-authenticating: #{e.message}")
        nil
      end

      def authenticate
        raise Client::Error, "CJ API key is not configured" if credentials.blank?

        client.request(:post, "/authentication/getAccessToken", payload: credentials, authenticated: false)["data"]
      end

      def credentials
        return { apiKey: client.api_key } if client.api_key.present?

        {}
      end

      def persist(data)
        raise Client::Error, "CJ did not return an access token" if data.blank? || data["accessToken"].blank?

        store.update!(
          supplier_settings: store.supplier_settings.merge(
            "access_token" => data["accessToken"],
            "access_token_expires_at" => data["accessTokenExpiryDate"],
            "refresh_token" => data["refreshToken"].presence || store.supplier_settings["refresh_token"],
            "refresh_token_expires_at" => data["refreshTokenExpiryDate"].presence || store.supplier_settings["refresh_token_expires_at"]
          )
        )

        data["accessToken"]
      end

      def expired?(value)
        return true if value.blank?

        deadline = Time.zone.parse(value.to_s)
        return true if deadline.blank?

        deadline <= Time.current + REFRESH_MARGIN
      rescue ArgumentError
        true
      end
    end
  end
end
