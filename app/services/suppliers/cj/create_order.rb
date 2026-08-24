module Suppliers
  module Cj
    class CreateOrder < ApplicationService
      ENDPOINT = "/shopping/order/createOrderV2".freeze
      # 1 = pay on CJ's page, 2 = deduct from CJ balance, 3 = create only.
      # Balance keeps fulfillment hands-off, which is the point of the pipeline.
      DEFAULT_PAY_TYPE = 2
      DEFAULT_FROM_COUNTRY = "CN".freeze

      def initialize(client:, order:)
        @client = client
        @order = order
      end

      def call
        order.with_lock do
          return order if order.supplier_order_id.present?

          validate!
          data = client.post(ENDPOINT, payload)["data"] || {}

          order.update!(
            supplier_order_id: data["orderId"].presence || data["orderNum"].presence,
            supplier_status: data["orderStatus"].presence || "CREATED",
            submitted_to_supplier_at: Time.current,
            metadata: order.metadata.merge("cj_order" => data.slice("orderNumber", "orderAmount", "shipmentOrderId").compact)
          )
        end

        order
      end

      private

      attr_reader :client, :order

      def validate!
        raise Suppliers::InvalidOrder, "Order #{order.id} has no supplier variant id" if order.supplier_variant_id.blank?
        raise Suppliers::InvalidOrder, "Order #{order.id} has no shipping address" if order.address_line1.blank? || order.country.blank?
      end

      def payload
        {
          orderNumber: order_number,
          shippingCustomerName: order.customer_name.presence || order.email,
          shippingPhone: order.phone,
          shippingAddress: order.address_line1,
          shippingAddress2: order.address_line2,
          shippingCity: order.city,
          shippingProvince: order.province,
          shippingCountryCode: country_code,
          shippingCountry: Countries.name_for(country_code),
          shippingZip: order.postal_code,
          email: order.email,
          remark: order.store.name,
          fromCountryCode: setting("from_country_code", DEFAULT_FROM_COUNTRY),
          logisticName: setting("logistic_name", nil),
          payType: setting("pay_type", DEFAULT_PAY_TYPE).to_i,
          products: [ { vid: order.supplier_variant_id, quantity: order.quantity } ]
        }.compact_blank
      end

      # CJ rejects duplicate order numbers, so retries must reuse the same value.
      def order_number
        "ORD-#{order.id}"
      end

      def country_code
        order.country.to_s.upcase.presence
      end

      def setting(key, fallback)
        value = order.store.supplier_settings[key]
        value.presence || fallback
      end
    end
  end
end
