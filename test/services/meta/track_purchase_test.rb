require "test_helper"

module Meta
  class TrackPurchaseTest < ActiveJob::TestCase
    CONFIGURED = {
      "META_PIXEL_ID" => "2010109929639061",
      "META_CONVERSIONS_API_TOKEN" => "SECRET-TOKEN"
    }.freeze

    setup do
      cart = Cart.new(store: stores(:demo), session: {})
      cart.add(variants(:black))
      cart.add(variants(:blue))
      @orders = Orders::PlaceFromCart.call(store: stores(:demo), cart:, details: details)
      @orders.each { |order| order.update!(stripe_payment_intent_id: "pi_meta_test") }
    end

    def pay!
      @orders.each { |order| order.update!(status: :paid, paid_at: Time.current) }
    end

    test "sends one Purchase for a payment that produced several order rows" do
      pay!

      with_env(CONFIGURED) do
        assert_enqueued_jobs 1, only: MetaPurchaseJob do
          TrackPurchase.call(orders: [ @orders.first ])
        end
      end

      assert_equal [ @orders.map(&:id).sort ], enqueued_jobs.filter_map { |job|
        job["job_class"] == "MetaPurchaseJob" ? job["arguments"].first.sort : nil
      }
    end

    test "does not send a second Purchase for the same payment" do
      pay!

      with_env(CONFIGURED) do
        TrackPurchase.call(orders: @orders)

        assert_no_enqueued_jobs only: MetaPurchaseJob do
          TrackPurchase.call(orders: @orders)
          TrackPurchase.call(orders: [ @orders.last ])
        end
      end
    end

    test "sends nothing for a payment that never succeeded" do
      @orders.each { |order| order.update!(status: :failed) }

      with_env(CONFIGURED) do
        assert_no_enqueued_jobs only: MetaPurchaseJob do
          TrackPurchase.call(orders: @orders)
        end
      end
    end

    test "sends nothing while the Conversions API has no token" do
      pay!

      with_env(CONFIGURED.merge("META_CONVERSIONS_API_TOKEN" => nil)) do
        assert_no_enqueued_jobs only: MetaPurchaseJob do
          TrackPurchase.call(orders: @orders)
        end
      end

      assert_not @orders.first.reload.metadata.key?(TrackPurchase::GUARD)
    end

    test "still counts an order that has already moved on to the supplier" do
      pay!
      @orders.first.update!(status: :submitted_to_supplier)

      with_env(CONFIGURED) do
        assert_enqueued_jobs 1, only: MetaPurchaseJob do
          TrackPurchase.call(orders: [ @orders.last ])
        end
      end

      assert_equal @orders.map(&:id).sort, enqueued_jobs.last["arguments"].first.sort
    end

    test "swallows its own failure rather than taking the payment down with it" do
      pay!

      with_env(CONFIGURED) do
        raising = ->(*) { raise "queue unavailable" }

        stubbing(MetaPurchaseJob, :perform_later, raising) do
          assert_nothing_raised { TrackPurchase.call(orders: @orders) }
        end
      end
    end

    private

    def details
      CheckoutForm.new(
        email: "alexis@exemple.ca", first_name: "Alexis", last_name: "Giard",
        phone: "+1 514 555 0123", address_line1: "123 rue Sainte-Catherine",
        city: "Montreal", postal_code: "H2X 1Y6", country: "CA"
      )
    end
  end
end
