module Addresses
  # Looks up the address a customer is part way through typing.
  #
  # Never raises and never returns more than LIMIT rows: the dropdown is a
  # convenience, and a geocoder having a bad day must not stop anyone from
  # checking out.
  class Suggest < ApplicationService
    # Below three characters every street in the province matches.
    MIN_LENGTH = 3
    MAX_LENGTH = 120
    LIMIT = 6
    CACHE_TTL = 12.hours

    def initialize(query:, countries: [], mode: :address, session_token: nil, provider: Addresses.provider)
      @query = query.to_s.squish.first(MAX_LENGTH).to_s
      @countries = Array(countries).map { |code| code.to_s.strip.upcase }.compact_blank
      @mode = mode.to_s == "postal" ? :postal : :address
      @session_token = session_token.to_s.first(100)
      @provider = provider
    end

    # Rows come back as plain hashes rather than Suggestion structs, so a cached
    # entry still loads after a deploy that changes the struct.
    def call
      return [] if query.length < MIN_LENGTH

      # Everyone typing "123 rue Sainte-Cath" walks through the same handful of
      # prefixes, and the geocoder is the one part of checkout we do not run.
      return lookup if provider.respond_to?(:cacheable?) && !provider.cacheable?

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { lookup }
    end

    private

    attr_reader :query, :countries, :mode, :session_token, :provider

    def lookup
      suggestions = provider.search(query:, countries:, limit: LIMIT, session_token:)
        .select do |suggestion|
          mode == :postal ? suggestion.line1.blank? : suggestion.line1.present? || suggestion.place_id.present?
        end

      suggestions = matching_postal_suggestions(suggestions) if mode == :postal

      suggestions
        .uniq(&:label)
        .first(LIMIT)
        .map(&:to_h)
    end

    # Photon deliberately returns nearby postal areas when it cannot find an
    # exact code. That is useful on a map, but dangerous at checkout: J4J 2X7
    # must never become J4J 2V5. Keep only rows that extend the characters the
    # customer actually typed; a complete code therefore requires an exact hit.
    def matching_postal_suggestions(suggestions)
      prefix = Addresses::PostalCode.compact(query)
      suggestions.select do |suggestion|
        candidate = suggestion.postal_code.presence || suggestion.label
        Addresses::PostalCode.compact(candidate).start_with?(prefix)
      end
    end

    def cache_key
      [ "addresses/suggest/v3", provider.class.name, language, mode, countries.sort.join("-"), query.downcase ].join("/")
    end

    def language
      I18n.locale.to_s.start_with?("fr") ? "fr" : "en"
    end
  end
end
