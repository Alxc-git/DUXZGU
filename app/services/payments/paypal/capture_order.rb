module Payments
  module Paypal
    # Takes the money once the customer has approved the PayPal order, then marks
    # the Rails orders paid through the same path Stripe uses.
    #
    # Safe to run twice: PayPal answers an already-captured order with
    # ORDER_ALREADY_CAPTURED, which is read from the order itself rather than
    # treated as a failure — the webhook and the browser both land here.
    class CaptureOrder < ApplicationService
      Error = Class.new(StandardError)
      Result = Data.define(:capture_id, :orders)

      COMPLETED = %w[COMPLETED].freeze

      def initialize(store:, paypal_order_id:, orders: nil)
        @store = store
        @paypal_order_id = paypal_order_id.to_s
        @orders = orders
      end

      def call
        raise Error, "Commande PayPal inconnue" if paypal_order_id.blank?
        raise Error, "Aucune commande a payer" if scope.empty?

        capture = capture_remotely
        status = capture.dig("status")
        raise Error, "Paiement PayPal non complete (#{status})" unless COMPLETED.include?(status)

        capture_id = extract_capture_id(capture)
        finalise(capture_id)

        Result.new(capture_id:, orders: scope)
      rescue Client::Error => e
        raise Error, e.message
      end

      private

      attr_reader :store, :paypal_order_id

      def scope
        @scope ||= (@orders.presence || store.orders.where(paypal_order_id:).to_a)
      end

      def capture_remotely
        Client.post("/v2/checkout/orders/#{paypal_order_id}/capture", {})
      rescue Client::Error => e
        # A second capture attempt is not an error: read the order back and use
        # the capture that already succeeded.
        raise e unless e.message.include?("ORDER_ALREADY_CAPTURED")

        Client.get("/v2/checkout/orders/#{paypal_order_id}")
      end

      def extract_capture_id(body)
        body.dig("purchase_units", 0, "payments", "captures", 0, "id").presence ||
          raise(Error, "PayPal n'a pas retourne d'identifiant de capture")
      end

      def finalise(capture_id)
        scope.each { |order| order.update!(paypal_capture_id: capture_id) }

        # Reuses the Stripe path so fulfillment, the confirmation page and the
        # admin behave identically whichever way the customer paid.
        MarkOrdersPaid.call(intent_id: nil, orders: scope, metadata: { "paypal_capture_id" => capture_id })
      end
    end
  end
end
