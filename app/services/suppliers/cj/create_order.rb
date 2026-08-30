module Suppliers
  module Cj
    class CreateOrder < ApplicationService
      ENDPOINT = "/shopping/order/createOrderV2".freeze
      # 1 = create the order and return CJ's hosted payment page. The merchant
      # pays each order manually because CJ balance deposits are not available
      # in every country. 2 would deduct from the prepaid CJ balance.
      DEFAULT_PAY_TYPE = 1
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
          clean_metadata = order.metadata.except("fulfillment_error", "fulfillment_failed_at")

          order.update!(
            supplier_order_id: data["orderId"].presence || data["orderNum"].presence,
            supplier_status: data["orderStatus"].presence || "CREATED",
            submitted_to_supplier_at: Time.current,
            metadata: clean_metadata.merge(
              "cj_order" => data.slice(
                "orderNumber", "orderAmount", "shipmentOrderId", "cjPayUrl", "payId"
              ).compact.merge("payType" => setting("pay_type", DEFAULT_PAY_TYPE).to_i)
            )
          )
        end

        order
      end

      private

      attr_reader :client, :order

      def validate!
        raise Suppliers::InvalidOrder, "Order #{order.id} has no supplier variant id" if order.supplier_variant_id.blank?
        raise Suppliers::InvalidOrder, "Order #{order.id} has no shipping address" if order.address_line1.blank? || order.country.blank?
        raise Suppliers::InvalidOrder, "Order #{order.id} has no valid shipping phone" unless ShippingPhone.valid?(order.phone)
      end

      def payload
        {
          orderNumber: order_number,
          shippingCustomerName: order.customer_name.presence || order.email,
          shippingPhone: ShippingPhone.normalize(order.phone),
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
          # The carrier quoted at checkout, so the parcel ships the way the
          # customer was promised. Falls back to the store setting, then to CJ's
          # own choice when neither is set.
          logisticName: order.shipping_carrier.presence || setting("logistic_name", nil),
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
