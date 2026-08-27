require "test_helper"

class RetryFailedFulfillmentJobTest < ActiveJob::TestCase
  setup do
    @order = orders(:paid_order)
    @order.update!(status: :paid, supplier_order_id: nil, paid_at: 1.hour.ago)
  end

  test "an order paid but never sent to the supplier is offered again" do
    assert_enqueued_with(job: FulfillOrderJob, args: [ @order.id ]) do
      RetryFailedFulfillmentJob.perform_now
    end
  end

  test "an order still inside its own retry window is left alone" do
    @order.update!(paid_at: 2.minutes.ago)

    assert_no_enqueued_jobs(only: FulfillOrderJob) { RetryFailedFulfillmentJob.perform_now }
  end

  test "an order already sent to the supplier is not resent" do
    @order.update!(supplier_order_id: "CJ-123")

    assert_no_enqueued_jobs(only: FulfillOrderJob) { RetryFailedFulfillmentJob.perform_now }
  end

  test "an order too old to be worth retrying is skipped" do
    @order.update!(paid_at: 45.days.ago)

    assert_no_enqueued_jobs(only: FulfillOrderJob) { RetryFailedFulfillmentJob.perform_now }
  end
end
