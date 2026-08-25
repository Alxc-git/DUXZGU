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
