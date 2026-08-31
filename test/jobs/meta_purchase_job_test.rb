require "test_helper"

class MetaPurchaseJobTest < ActiveJob::TestCase
  CONFIGURED = {
    "META_PIXEL_ID" => "2010109929639061",
    "META_CONVERSIONS_API_TOKEN" => "SECRET-TOKEN"
  }.freeze

  setup do
    @order = orders(:paid_order)
    @order.update!(paid_at: Time.current, metadata: { "checkout_reference" => "LX-JOB1234" })
  end

  # Records what would have been sent instead of opening a socket.
  def recording
    sent = []
    stubbing(Meta::ConversionsApi, :call, ->(**payload) { sent << payload }) { yield sent }
    sent
  end

  test "sends the Purchase built from the orders it was given" do
    with_env(CONFIGURED) do
      sent = recording { MetaPurchaseJob.perform_now([ @order.id ]) }

      assert_equal 1, sent.size
      assert_equal "Purchase", sent.first[:event_name]
      assert_equal "purchase_stripe_pi_paid", sent.first[:event_id]
      assert_in_delta 49.0, sent.first[:custom_data][:value], 0.001
    end
  end

  test "records that the event went out" do
    with_env(CONFIGURED) do
      recording { MetaPurchaseJob.perform_now([ @order.id ]) }
    end

    assert @order.reload.metadata[MetaPurchaseJob::SENT_AT].present?
  end

  test "does not send the same purchase twice" do
    with_env(CONFIGURED) do
      sent = recording do
        MetaPurchaseJob.perform_now([ @order.id ])
        MetaPurchaseJob.perform_now([ @order.id ])
      end

      assert_equal 1, sent.size
    end
  end

  test "retries and leaves the order untouched when Meta refuses the event" do
    with_env(CONFIGURED) do
      refusing = ->(**) { raise Meta::ConversionsApi::Error, "status=500" }

      stubbing(Meta::ConversionsApi, :call, refusing) do
        # retry_on catches it: the conversion is worth another attempt, and the
        # stable event id means a retry cannot double count the sale.
        assert_enqueued_jobs 1, only: MetaPurchaseJob do
          MetaPurchaseJob.perform_now([ @order.id ])
        end
      end
    end

    @order.reload
    assert_predicate @order, :paid?
    assert_not @order.metadata.key?(MetaPurchaseJob::SENT_AT)
  end

  test "does nothing when the orders are gone" do
    with_env(CONFIGURED) do
      sent = recording { MetaPurchaseJob.perform_now([ 0 ]) }

      assert_empty sent
    end
  end
end
