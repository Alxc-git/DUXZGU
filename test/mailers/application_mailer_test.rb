require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "the fallback sender is the public support contact address" do
    assert_equal "contact@example.com", ApplicationMailer.default[:from]
  end
end
