require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "the fallback sender is the public LUXTIME contact address" do
    assert_equal "contact@luxtimestyle.com", ApplicationMailer.default[:from]
  end
end
