module Suppliers
  module Cj
    # Asks CJ how long a parcel actually takes to reach this address, rather than
    # repeating one hardcoded range to everyone.
    #
    # CJ answers with a list of carriers, each carrying a price and an aging like
    # "4-7" in days. The chosen carrier is stored on the order and passed back to
    # CJ at fulfillment, so the parcel ships the way the customer was promised.
    class DeliveryEstimate < ApplicationService
      ENDPOINT = "/logistic/freightCalculate".freeze
      FROM_COUNTRY = "CN".freeze
      # CJ hands the parcel over after picking and packing; the aging it quotes
      # starts from that handover, not from the moment the customer pays.
      HANDLING_DAYS = 2
      # The cheapest carrier is often the slowest by a week. Options costing up to
      # this multiple of the cheapest stay in the running, and the fastest of them
      # wins: a few cents of margin buys a promise the customer will accept.
      PRICE_TOLERANCE = 1.6
      # The shared CJ client waits up to 30s. That is fine for fulfillment, which
      # runs in a job, but this call sits in the middle of a checkout: past a few
      # seconds it is better to ship the generic promise than to make the customer
      # stare at a spinner.
      BUDGET_SECONDS = 4

      Result = Data.define(:min_days, :max_days, :carrier, :price_cents) do
        # Business days are what a customer counts, so the window is expressed in
        # calendar days from today with the handling time already included.
        def min_date(today: Date.current)
          today + min_days
        end

        def max_date(today: Date.current)
          today + max_days
        end
      end

      def initialize(client:, country:, postal_code:, variant_ids:, quantity: 1)
        @client = client
        @country = country.to_s.upcase
        @postal_code = postal_code.to_s.delete(" ").upcase
        @variant_ids = Array(variant_ids).compact_blank
        @quantity = quantity
      end

      def call
        return if country.blank? || variant_ids.empty?

        response = Timeout.timeout(BUDGET_SECONDS) { client.post(ENDPOINT, payload) }
        parsed = Array(response["data"]).filter_map { |option| parse(option) }
        return if parsed.empty?

        floor = parsed.min_by(&:price_cents).price_cents
        affordable = parsed.select { |option| option.price_cents <= floor * PRICE_TOLERANCE }
        affordable.min_by { |option| [ option.max_days, option.price_cents ] }
      rescue Timeout::Error
        Rails.logger.warn("[CJ] estimation abandonnee apres #{BUDGET_SECONDS}s")
        nil
      rescue Suppliers::Cj::Client::Error => e
        # An estimate is a nicety: never let it block a checkout.
        Rails.logger.warn("[CJ] estimation de livraison indisponible: #{e.message}")
        nil
      end

      private

      attr_reader :client, :country, :postal_code, :variant_ids, :quantity

      def payload
        {
          startCountryCode: FROM_COUNTRY,
          endCountryCode: country,
          zip: postal_code,
          products: variant_ids.map { |vid| { vid:, quantity: } }
        }
      end

      # "4-7" and "7-15" are the shapes CJ returns; a single number appears too.
      def parse(option)
        aging = option["logisticAging"].to_s
        days = aging.scan(/\d+/).map(&:to_i)
        return if days.empty?

        Result.new(
          min_days: days.min + HANDLING_DAYS,
          max_days: days.max + HANDLING_DAYS,
          carrier: option["logisticName"].to_s.presence,
          price_cents: (option["logisticPrice"].to_f * 100).round
        )
      end
    end
  end
end
