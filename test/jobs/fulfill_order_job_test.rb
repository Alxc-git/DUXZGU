require "test_helper"

class FulfillOrderJobTest < ActiveJob::TestCase
  test "submits paid order to supplier" do
    order = orders(:paid_order)
    supplier = OpenStruct.new
    supplier.define_singleton_method(:create_order) do |record|
      record.update!(supplier_order_id: "cj-job", supplier_status: "submitted", submitted_to_supplier_at: Time.current)
    end

    with_supplier_stub(supplier) do
      FulfillOrderJob.perform_now(order.id)
    end

    assert_predicate order.reload, :submitted_to_supplier?
    assert_equal "cj-job", order.supplier_order_id
  end

  private

  def with_supplier_stub(supplier)
    original = Suppliers.method(:for)
    Suppliers.define_singleton_method(:for) { |_store| supplier }
    yield
  ensure
    Suppliers.define_singleton_method(:for, original)
  end

  test "a supplier refusal does not erase the fact that the order was paid" do
    order = orders(:paid_order)
    order.update!(status: :paid, paid_at: Time.current)
    order.product.update!(supplier_product_id: "", supplier_variant_id: "")
    order.variant&.update!(supplier_variant_id: "")

    perform_enqueued_jobs { FulfillOrderJob.perform_now(order.id) }

    order.reload
    assert_predicate order, :paid?
    assert_equal "failed", order.supplier_status
    assert_match "supplier variant", order.metadata["fulfillment_error"]
    assert_not_nil order.paid_at
  end

  test "an unpaid order is never sent to the supplier" do
    order = orders(:paid_order)
    order.update!(status: :pending, paid_at: nil)

    perform_enqueued_jobs { FulfillOrderJob.perform_now(order.id) }

    order.reload
    assert_predicate order, :pending?
    assert_nil order.supplier_status
  end
end
