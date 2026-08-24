require "test_helper"

class StoreTest < ActiveSupport::TestCase
  test "resolves active store from request host" do
    assert_equal stores(:demo), Store.resolve("localhost:3000")
  end

  test "falls back to first active store for localhost-like development hosts" do
    assert Store.resolve("127.0.0.1")
  end
end
