require "test_helper"

class RecentPurchaseTest < ActiveSupport::TestCase
  setup do
    @store = stores(:demo)
    @order = @store.orders.first
  end

  def widen(hours) = @store.update!(settings: @store.settings.merge(RecentPurchase::WINDOW_SETTING => hours))
  def names(style) = @store.update!(settings: @store.settings.merge(RecentPurchase::NAME_SETTING => style))

  # The fixtures carry two orders; the notice threshold is higher than that, so
  # the rest are built here rather than bloating the fixture file.
  def paid_recently(count, city: "Lyon", first_name: "Genevieve")
    template = @store.orders.first

    count.times do |i|
      order = i.zero? ? template : template.dup
      if order.new_record?
        # The checkout ids are unique per order; a duplicate would collide.
        order.stripe_checkout_session_id = "cs_copy_#{i}"
        order.stripe_payment_intent_id = "pi_copy_#{i}"
        order.save!(validate: false)
      end
      order.update_columns(paid_at: (i + 1).hours.ago, city:, first_name:)
    end
  end

  test "only paid orders are published" do
    @store.orders.update_all(paid_at: nil)

    assert_empty RecentPurchase.for(@store)
  end

  test "orders older than the window are left out" do
    @store.orders.update_all(paid_at: 10.days.ago, city: "Lyon")

    assert_empty RecentPurchase.for(@store)
  end

  test "the window is a store setting" do
    paid_recently(RecentPurchase::MIN_FOR_NOTICES)
    @store.orders.update_all(paid_at: 10.days.ago)

    assert_empty RecentPurchase.for(@store), "10 days is outside the default window"

    widen(24 * 30)

    assert_predicate RecentPurchase.for(@store), :any?
  end

  test "a handful of orders is not enough for individual notices" do
    @store.orders.update_all(paid_at: nil)
    paid_recently(RecentPurchase::MIN_FOR_NOTICES - 1)

    assert_empty RecentPurchase.for(@store)
  end

  test "an order without a city is skipped" do
    @store.orders.update_all(paid_at: 1.hour.ago, city: "")

    assert_empty RecentPurchase.for(@store).map(&:city)
  end

  test "only an initial is published by default" do
    paid_recently(RecentPurchase::MIN_FOR_NOTICES)
    entry = RecentPurchase.for(@store).first

    assert_equal "G.", entry.who
    assert_not_includes entry.to_h.to_s, "Genevieve"
  end

  test "a store can opt into publishing first names" do
    paid_recently(RecentPurchase::MIN_FOR_NOTICES)
    names("first_name")

    assert_equal "Genevieve", RecentPurchase.for(@store).first.who
  end

  test "an unknown name style falls back to the initial" do
    paid_recently(RecentPurchase::MIN_FOR_NOTICES)
    names("full_name_and_address")

    assert_equal "G.", RecentPurchase.for(@store).first.who
  end

  test "a missing name degrades to someone rather than blank" do
    paid_recently(RecentPurchase::MIN_FOR_NOTICES, first_name: nil)

    assert_equal "Someone", RecentPurchase.for(@store).first.who
  end

  test "the summary counts real orders over the longer window" do
    @store.orders.update_all(paid_at: nil)
    paid_recently(RecentPurchase::MIN_FOR_NOTICES)

    assert_equal RecentPurchase::MIN_FOR_NOTICES, RecentPurchase.summary(@store)[:count]
  end

  test "the summary stays silent when there is almost nothing to report" do
    @store.orders.update_all(paid_at: nil)
    paid_recently(1)

    assert_nil RecentPurchase.summary(@store)
  end

  test "no store means no entries and no summary" do
    assert_empty RecentPurchase.for(nil)
    assert_nil RecentPurchase.summary(nil)
  end
end
