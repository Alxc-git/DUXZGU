require "test_helper"

module Suppliers
  module Cj
    class CreateOrderTest < ActiveSupport::TestCase
      test "does not create duplicate supplier orders" do
        order = orders(:paid_order)
        calls = 0
        client = stub_client { calls += 1 }

        Suppliers::Cj::CreateOrder.call(client:, order:)
        Suppliers::Cj::CreateOrder.call(client:, order:)

        assert_equal 1, calls
        assert_equal "cj-new", order.reload.supplier_order_id
      end

      test "posts a flat CJ v2 payload with the variant vid" do
        order = orders(:paid_order)
        order.update!(variant: variants(:black), supplier_order_id: nil)
        captured = nil
        client = stub_client { |path, payload| captured = [ path, payload ] }

        Suppliers::Cj::CreateOrder.call(client:, order:)

        path, payload = captured
        assert_equal "/shopping/order/createOrderV2", path
        assert_equal "ORD-#{order.id}", payload[:orderNumber]
        assert_equal "Ada Lovelace", payload[:shippingCustomerName]
        assert_equal "1250 rue Sainte-Catherine O", payload[:shippingAddress]
        assert_equal "Montreal", payload[:shippingCity]
        assert_equal "QC", payload[:shippingProvince]
        assert_equal "CA", payload[:shippingCountryCode]
        assert_equal "Canada", payload[:shippingCountry]
        assert_equal "H3G 1P1", payload[:shippingZip]
        assert_equal [ { vid: "cj-variant-black", quantity: 1 } ], payload[:products]
      end

      test "reads pay type, warehouse and carrier from supplier settings" do
        order = orders(:paid_order)
        order.update!(supplier_order_id: nil)
        order.store.update!(supplier_settings: {
          "pay_type" => 3, "from_country_code" => "US", "logistic_name" => "CJPacket Ordinary"
        })
        captured = nil
        client = stub_client { |_path, payload| captured = payload }

        Suppliers::Cj::CreateOrder.call(client:, order:)

        assert_equal 3, captured[:payType]
        assert_equal "US", captured[:fromCountryCode]
        assert_equal "CJPacket Ordinary", captured[:logisticName]
      end

      test "refuses an order without a shipping address instead of retrying forever" do
        order = orders(:paid_order)
        order.update!(supplier_order_id: nil, address_line1: nil)

        assert_raises(Suppliers::InvalidOrder) do
          Suppliers::Cj::CreateOrder.call(client: stub_client, order:)
        end
      end

      test "refuses an order whose variant is not mapped to CJ" do
        order = orders(:paid_order)
        order.update!(supplier_order_id: nil)
        order.product.update!(supplier_variant_id: nil)

        assert_raises(Suppliers::InvalidOrder) do
          Suppliers::Cj::CreateOrder.call(client: stub_client, order: order.reload)
        end
      end

      private

      def stub_client(&recorder)
        client = Object.new
        client.define_singleton_method(:post) do |path, payload|
          recorder&.call(path, payload)
          { "data" => { "orderId" => "cj-new", "orderStatus" => "CREATED" } }
        end
        client
      end
    end
  end
end
