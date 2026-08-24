require "test_helper"

class UpdateTrackingJobTest < ActiveJob::TestCase
  test "marks an order shipped and stores the tracking link" do
    order = orders(:submitted_order)

    with_supplier_stub(tracking: {
      tracking_number: "CJ123456789CN",
      tracking_url: "https://track.test/CJ123456789CN",
      supplier_status: "SHIPPED"
    }) { UpdateTrackingJob.perform_now(order.id) }

    order.reload
    assert_predicate order, :shipped?
    assert_equal "CJ123456789CN", order.tracking_number
    assert_equal "https://track.test/CJ123456789CN", order.tracking_url
    assert_not_nil order.shipped_at
  end

  test "moves a shipped order to delivered" do
    order = orders(:submitted_order)
    order.update!(status: :shipped, shipped_at: 3.days.ago)

    with_supplier_stub(tracking: { tracking_number: "CJ1", supplier_status: "DELIVERED" }) do
      UpdateTrackingJob.perform_now(order.id)
    end

    order.reload
    assert_predicate order, :delivered?
    assert_not_nil order.delivered_at
  end

  test "keeps the order in place while CJ is still processing it" do
    order = orders(:submitted_order)

    with_supplier_stub(tracking: { tracking_number: nil, supplier_status: "PROCESSING" }) do
      UpdateTrackingJob.perform_now(order.id)
    end

    order.reload
    assert_predicate order, :submitted_to_supplier?
    assert_equal "PROCESSING", order.supplier_status
  end

  test "a failing order does not abort the sweep" do
    failing = orders(:submitted_order)
    supplier = Object.new
    supplier.define_singleton_method(:tracking) do |_order|
      raise Suppliers::Cj::Client::Error, "CJ down"
    end

    with_supplier_stub(supplier: supplier) { UpdateTrackingJob.perform_now }

    assert_predicate failing.reload, :submitted_to_supplier?
  end

  private

  def with_supplier_stub(tracking: nil, supplier: nil)
    supplier ||= Object.new.tap do |double|
      double.define_singleton_method(:tracking) { |_order| tracking }
    end
    original = Suppliers.method(:for)
    Suppliers.define_singleton_method(:for) { |_store| supplier }
    yield
  ensure
    Suppliers.define_singleton_method(:for, original)
  end
end
