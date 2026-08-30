require "test_helper"

class ShippingPhoneTest < ActiveSupport::TestCase
  test "accepts and normalizes a Canadian phone" do
    assert ShippingPhone.valid?("+1 (514) 555-0142")
    assert_equal "+15145550142", ShippingPhone.normalize("+1 (514) 555-0142")
  end

  test "rejects a blank or alphabetic phone" do
    assert_not ShippingPhone.valid?(nil)
    assert_not ShippingPhone.valid?("call me")
  end
end
