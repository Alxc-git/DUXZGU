require "test_helper"

class Admin::FulfillmentControllerTest < ActionDispatch::IntegrationTest
  setup do
    post admin_login_path, params: { email: "admin@example.com", password: "password12345" }

    @order = orders(:paid_order)
    @order.update!(
      status: :paid, supplier_order_id: nil, supplier_status: "failed", paid_at: 1.hour.ago
    )
  end

  test "the panel lists a customer who paid but whose order never reached CJ" do
    get admin_fulfillment_path

    assert_response :success
    assert_match "Ada Lovelace", response.body
    assert_match @order.email, response.body
  end

  # The whole point of the panel: knowing how much to top the CJ balance up by,
  # which is the supplier cost and never the revenue the customer paid.
  test "the credit needed is the supplier cost, not what the customer paid" do
    get admin_fulfillment_path

    assert_response :success
    assert_equal 1800, @order.supplier_cost_cents
    assert_equal 4900, @order.total_cents
    assert_match MoneyFormatter.format(1800, @order.currency), response.body
  end

  test "the credit needed adds up across every blocked order" do
    2.times do |n|
      @order.dup.update!(supplier_order_id: nil, status: :paid, paid_at: 1.hour.ago,
                         stripe_checkout_session_id: "cs_extra_#{n}")
    end

    get admin_fulfillment_path

    assert_response :success
    assert_match MoneyFormatter.format(5400, @order.currency), response.body
  end

  # When the button cannot get an order through, the fallback is retyping it into
  # CJ's own form. Everything that takes -- address, phone, and above all the CJ
  # variant id that picks the right colour -- has to be on this page, or the
  # parcel goes out wrong.
  test "a blocked order carries everything needed to order it by hand" do
    @order.update!(
      first_name: "Marc", last_name: "Tremblay", phone: "+15145550142",
      address_line1: "1250 rue Sainte-Catherine O", address_line2: "App 302",
      city: "Montreal", province: "QC", postal_code: "H3G 1P5", country: "CA"
    )

    get admin_fulfillment_path

    assert_response :success
    assert_match "Marc Tremblay", response.body
    assert_match "1250 rue Sainte-Catherine O", response.body
    assert_match "App 302", response.body
    assert_match "H3G 1P5", response.body
    assert_match "+15145550142", response.body
    assert_match @order.supplier_variant_id, response.body
    assert_match "ORD-#{@order.id}", response.body
  end

  test "an order already accepted by CJ is not counted as blocked" do
    @order.update!(supplier_order_id: "CJ-123", status: :submitted_to_supplier)

    get admin_fulfillment_path

    assert_response :success
    assert_match "Rien en attente", response.body
  end

  test "retry all re-offers every blocked order" do
    assert_enqueued_with(job: FulfillOrderJob, args: [ @order.id ]) do
      post retry_all_admin_fulfillment_path
    end

    assert_redirected_to admin_fulfillment_path
  end

  test "retry all says so plainly when there is nothing to send" do
    @order.update!(supplier_order_id: "CJ-123")

    assert_no_enqueued_jobs(only: FulfillOrderJob) { post retry_all_admin_fulfillment_path }
    assert_match "Aucune commande en attente", flash[:notice]
  end

  test "the panel needs a signed-in admin" do
    delete admin_logout_path
    get admin_fulfillment_path

    assert_redirected_to admin_login_path
  end
end
