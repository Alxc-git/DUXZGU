require "test_helper"

class AdminAuthenticationTest < ActionDispatch::IntegrationTest
  test "protects admin routes" do
    get admin_root_path
    assert_redirected_to admin_login_path
  end

  test "allows admin login" do
    post admin_login_path, params: { email: "admin@example.com", password: "password12345" }
    assert_redirected_to admin_root_path
  end
end
