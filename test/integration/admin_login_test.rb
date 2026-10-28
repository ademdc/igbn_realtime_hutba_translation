require "test_helper"

class AdminLoginTest < ActionDispatch::IntegrationTest
  test "super admin logs in with email and password" do
    host! "localhost"
    post "/admin/login", params: { email: "admin@hutba.test", password: "password1234" }
    assert_redirected_to "http://localhost/admin/dashboard"
    follow_redirect!
    assert_response :success
  end

  test "mosque owners cannot use the admin login" do
    host! "demo.localhost"
    post "/admin/login", params: { email: "owner@demo.test", password: "password1234" }
    assert_response :unprocessable_entity
  end
end
