module Addresses
  class Details < ApplicationService
    def initialize(place_id:, session_token:, countries:, provider: Addresses.provider)
      @place_id = place_id.to_s
      @session_token = session_token.to_s
      @countries = Array(countries).map { |country| country.to_s.upcase }.compact_blank
      @provider = provider
    end

    def call
      return unless provider.respond_to?(:details)

      suggestion = provider.details(place_id:, countries:, session_token:)
      return if suggestion.nil?
      return if countries.present? && suggestion.country.present? && !suggestion.country.in?(countries)

      suggestion.to_h
    end

    private

    attr_reader :place_id, :session_token, :countries, :provider
  end
end
