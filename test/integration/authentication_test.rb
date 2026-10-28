require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { host! "demo.localhost" }

  test "owner logs in and lands on the dashboard" do
    post "/login", params: { email: "OWNER@demo.test ", password: "password1234" }
    assert_redirected_to "http://demo.localhost/dashboard"
    follow_redirect!
    assert_response :success
    assert_select "h1", /Emir Demo/
  end

  test "speaker logs in and lands on the speaker panel" do
    post "/login", params: { email: "imam@demo.test", password: "password1234" }
    assert_redirected_to "http://demo.localhost/"
    follow_redirect!
    assert_response :success

    get "/dashboard"
    assert_response :forbidden
  end

  test "chosen language survives login" do
    get "/login", params: { locale: "bs" }
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
    follow_redirect!
    assert_select "html[lang=bs]"
  end

  test "wrong password is rejected" do
    post "/login", params: { email: "owner@demo.test", password: "nope" }
    assert_response :unprocessable_entity
  end

  test "users cannot log in to another mosque" do
    host! "igbd-nuernberg.localhost"
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
    assert_response :unprocessable_entity
  end

  test "dashboard requires login" do
    get "/dashboard"
    assert_redirected_to "http://demo.localhost/login"
  end

  test "logout ends the session" do
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
    delete "/logout"
    get "/dashboard"
    assert_redirected_to "http://demo.localhost/login"
  end

  test "changing the password logs out other sessions" do
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
    users(:demo_owner).update!(password: "anotherpassword")
    get "/dashboard"
    assert_redirected_to "http://demo.localhost/login"
  end

  test "password reset flow" do
    assert_enqueued_emails 1 do
      post "/password_resets", params: { email: "owner@demo.test" }
    end
    assert_redirected_to "http://demo.localhost/login"

    token = users(:demo_owner).generate_token_for(:password_reset)
    get "/password_resets/#{token}/edit"
    assert_response :success

    patch "/password_resets/#{token}", params: { user: { password: "brandnewpassword", password_confirmation: "brandnewpassword" } }
    assert_redirected_to "http://demo.localhost/dashboard"
    assert users(:demo_owner).reload.authenticate("brandnewpassword")

    # Token is single-use
    get "/password_resets/#{token}/edit"
    assert_redirected_to "http://demo.localhost/password_resets/new"
  end

  test "password reset does not reveal unknown addresses" do
    assert_no_enqueued_emails do
      post "/password_resets", params: { email: "nobody@example.com" }
    end
    assert_redirected_to "http://demo.localhost/login"
  end

  test "password reset token from another mosque is rejected" do
    token = users(:igbd_owner).generate_token_for(:password_reset)
    get "/password_resets/#{token}/edit"
    assert_redirected_to "http://demo.localhost/password_resets/new"
  end

  test "password reset rejects short or blank passwords" do
    token = users(:demo_owner).generate_token_for(:password_reset)
    patch "/password_resets/#{token}", params: { user: { password: "", password_confirmation: "" } }
    assert_response :unprocessable_entity
    patch "/password_resets/#{token}", params: { user: { password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity
  end

  test "signed-in users can open the speaker panel without the PIN" do
    post "/login", params: { email: "imam@demo.test", password: "password1234" }
    get "/"
    assert_response :success
  end
end
