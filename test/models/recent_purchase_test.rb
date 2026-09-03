require "test_helper"

class RecentPurchaseTest < ActiveSupport::TestCase
  setup { @store = stores(:demo) }

  test "only paid orders are published" do
    @store.orders.update_all(paid_at: nil)

    assert_empty RecentPurchase.for(@store)
  end

  test "an order without a city is skipped" do
    order = @store.orders.first
    order.update_columns(paid_at: 1.hour.ago, city: "")

    assert_not_includes RecentPurchase.for(@store).map(&:city), ""
  end

  test "orders older than the window are left out" do
    @store.orders.update_all(paid_at: (RecentPurchase::WINDOW + 1.day).ago)

    assert_empty RecentPurchase.for(@store)
  end

  test "a full first name is never published, only its initial" do
    order = @store.orders.first
    order.update_columns(paid_at: 1.hour.ago, first_name: "Genevieve", city: "Lyon")

    entry = RecentPurchase.for(@store).first

    assert_equal "G.", entry.who
    assert_not_includes entry.to_h.to_s, "Genevieve"
  end

  test "a missing name degrades to someone rather than blank" do
    order = @store.orders.first
    order.update_columns(paid_at: 1.hour.ago, first_name: nil, city: "Lyon")

    assert_equal "Someone", RecentPurchase.for(@store).first.who
  end

  test "no store means no entries" do
    assert_empty RecentPurchase.for(nil)
  end
end
