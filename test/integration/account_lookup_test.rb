require "test_helper"

class AccountLookupTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { host! "localhost" }

  test "sends login links for known addresses" do
    get "/de/login"
    assert_response :success

    assert_enqueued_emails 1 do
      post "/de/login", params: { email: "owner@demo.test" }
    end
    assert_redirected_to "http://localhost/de/login"
  end

  test "gives the same answer for unknown addresses" do
    assert_no_enqueued_emails do
      post "/en/login", params: { email: "nobody@example.com" }
    end
    assert_redirected_to "http://localhost/en/login"
  end
end
