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
end
