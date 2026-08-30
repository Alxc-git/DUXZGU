require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "resolves active store from request host" do
    assert_equal stores(:demo), Store.resolve("localhost:3000")
  end

  test "falls back to first active store for localhost-like development hosts" do
    assert Store.resolve("127.0.0.1")
  end

  test "a freshly deployed host falls back to the only active store" do
    Store.where.not(id: stores(:demo).id).destroy_all
    stores(:demo).update!(domain: "localhost", active: true)

    assert_equal stores(:demo), in_production { Store.resolve("luxtime.up.railway.app") }
  end

  test "an unknown host is refused once a second store exists" do
    stores(:demo).update!(domain: "localhost", active: true)
    stores(:other).update!(domain: "autre.example", active: true)

    resolved = in_production { Store.resolve("inconnu.example") }

    assert_nil resolved, "with two shops the domain has to match, guessing would show the wrong prices"
  end

  test "Luxtime uses the official support email by default" do
    store = stores(:demo)
    store.update!(name: "LUXTIME", slug: "luxtime", settings: store.settings.except("support_email"))

    assert_equal "contact@luxtimestyle.com", store.support_email
  end

  test "public contact settings can be managed through the store" do
    store = stores(:demo)

    store.support_email = " boutique@example.com "
    store.legal_business_name = " Example Watches Inc. "
    store.business_phone = " +1 514 555-0100 "
    store.save!

    assert_equal "boutique@example.com", store.reload.support_email
    assert_equal "Example Watches Inc.", store.legal_business_name
    assert_equal "+1 514 555-0100", store.business_phone
  end

  test "CJ uses manual payment when no pay type is configured" do
    store = stores(:demo)
    store.update!(supplier_settings: store.supplier_settings.except("pay_type"))

    assert_equal 1, store.cj_pay_type
    assert_predicate store, :manual_cj_payment?
  end

  private

  # The fallback only applies outside development and test, which is exactly the
  # branch a deployment takes.
  def in_production
    original = Rails.env
    Rails.env = "production"
    yield
  ensure
    Rails.env = original
  end
end
