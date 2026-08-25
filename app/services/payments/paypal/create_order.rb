module Payments
  module Paypal
    # Opens a PayPal order covering every Rails order of one checkout, so the
    # customer approves a single amount — the same rule the Stripe intent follows.
    #
    # The amount is recomputed here from the orders rather than taken from the
    # browser: a total that arrived over the wire is a total a customer can edit.
    class CreateOrder < ApplicationService
      Error = Class.new(StandardError)

      def initialize(store:, orders:)
        @store = store
        @orders = Array(orders)
      end

      def call
        raise Error, "Aucune commande a payer" if orders.empty?
        raise Error, "PayPal n'est pas configure" unless Payments.paypal_configured?

        response = Client.post("/v2/checkout/orders", payload, headers: idempotency_header)
        paypal_id = response["id"].presence or raise Error, "PayPal n'a pas retourne d'identifiant"

        orders.each { |order| order.update!(paypal_order_id: paypal_id) }
        paypal_id
      rescue Client::Error => e
        raise Error, e.message
      end

      private

      attr_reader :store, :orders

      def payload
        {
          intent: "CAPTURE",
          purchase_units: [ purchase_unit ],
          payment_source: {
            paypal: {
              experience_context: {
                brand_name: store.name.to_s.first(127),
                locale: store.checkout_locale,
                shipping_preference: "SET_PROVIDED_ADDRESS",
                user_action: "PAY_NOW"
              }
            }
          }
        }
      end

      def purchase_unit
        {
          reference_id: reference,
          custom_id: orders.map(&:id).join(","),
          description: orders.first.line_item_name.to_s.first(127),
          amount: amount,
          shipping: shipping
        }.compact
      end

      def amount
        {
          currency_code: currency,
          value: money(total_cents),
          breakdown: {
            item_total: { currency_code: currency, value: money(subtotal_cents) },
            shipping: { currency_code: currency, value: money(shipping_cents) }
          }
        }
      end

      def shipping
        first = orders.first
        return if first.address_line1.blank?

        {
          name: { full_name: first.customer_name.presence || first.email.to_s },
          address: {
            address_line_1: first.address_line1,
            address_line_2: first.address_line2.presence,
            admin_area_2: first.city,
            admin_area_1: first.province.presence,
            postal_code: first.postal_code,
            country_code: first.country.to_s.upcase
          }.compact
        }
      end

      def reference
        orders.first.metadata["checkout_reference"].presence || "ORD-#{orders.first.id}"
      end

      # Replaying the same checkout returns the existing PayPal order instead of
      # opening a second one, which is what a double click would otherwise do.
      def idempotency_header
        { "PayPal-Request-Id" => "luxtime-#{reference}" }
      end

      def currency
        orders.first.currency.to_s.upcase
      end

      def subtotal_cents
        orders.sum(&:subtotal_cents)
      end

      def shipping_cents
        orders.sum(&:shipping_cents)
      end

      def total_cents
        orders.sum(&:total_cents)
      end

      def money(cents)
        format("%.2f", cents.to_i / 100.0)
      end
    end
  end
end
