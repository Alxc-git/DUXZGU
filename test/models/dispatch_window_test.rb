require "test_helper"

class DispatchWindowTest < ActiveSupport::TestCase
  setup { @store = stores(:demo) }

  def window(at)
    DispatchWindow.for(@store, now: Time.zone.parse(at))
  end

  test "before the cutoff on a weekday the order ships today" do
    assert window("2026-09-02 09:00").same_day?
  end

  test "after the cutoff it no longer ships today" do
    assert_not window("2026-09-02 16:00").same_day?
  end

  test "after the cutoff the countdown rolls to the next working day" do
    assert_equal Date.new(2026, 9, 3), window("2026-09-02 16:00").ships_on
  end

  test "a weekend never claims a same-day dispatch" do
    saturday = window("2026-09-05 09:00")

    assert_not saturday.same_day?
    assert_equal Date.new(2026, 9, 7), saturday.ships_on
  end

  test "the cutoff hour is a store setting" do
    @store.update!(settings: @store.settings.merge(DispatchWindow::SETTING => 10))

    assert_not window("2026-09-02 11:00").same_day?
  end

  test "seconds left never runs negative" do
    assert_operator window("2026-09-02 16:00").seconds_left, :>=, 0
  end
end
