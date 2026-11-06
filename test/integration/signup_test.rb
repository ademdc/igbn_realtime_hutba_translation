require "test_helper"

class SignupTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { host! "localhost" }

  def valid_params(overrides = {})
    { signup: { mosque_name: "Džemat Stuttgart", subdomain: "dzemat-stuttgart", country: "DE", city: "Stuttgart",
                name: "Amir", email: "amir@example.com", password: "supersecret1", terms: "1" }.merge(overrides) }
  end

  test "signup creates a trial account and hands over to the subdomain" do
    get "/de/signup"
    assert_response :success

    assert_enqueued_emails 1 do
      post "/de/signup", params: valid_params
    end

    account = Account.find_by!(subdomain: "dzemat-stuttgart")
    assert_equal "trialing", account.status
    assert_equal %w[de], account.languages
    assert_in_delta 30.days.from_now, account.trial_ends_at, 1.minute

    owner = account.users.sole
    assert owner.owner?
    assert_equal "de", owner.locale

    assert_match %r{\Ahttp://dzemat-stuttgart\.localhost/session/}, response.location

    # Handover signs in on the subdomain
    host! "dzemat-stuttgart.localhost"
    get URI(response.location).request_uri
    assert_redirected_to "http://dzemat-stuttgart.localhost/dashboard?welcome=1"
    follow_redirect!
    assert_response :success
    assert_select ".welcome"
  end

  test "handover token works only once" do
    post "/de/signup", params: valid_params
    path = URI(response.location).path
    host! "dzemat-stuttgart.localhost"

    get path
    delete "/logout"
    get path
    assert_redirected_to "http://dzemat-stuttgart.localhost/login"
  end

  test "invalid signup shows errors" do
    post "/en/signup", params: valid_params(subdomain: "admin", email: "nope", terms: "0")
    assert_response :unprocessable_entity
    assert_select ".signup-form__errors li", minimum: 3
    assert_equal 0, Account.where(subdomain: "admin").count
  end

  test "taken subdomain is rejected" do
    post "/en/signup", params: valid_params(subdomain: "demo")
    assert_response :unprocessable_entity
  end

  test "subdomain check" do
    get "/en/signup/check", params: { subdomain: "demo" }
    assert_equal false, response.parsed_body["available"]

    get "/en/signup/check", params: { subdomain: "new-mosque" }
    assert_equal true, response.parsed_body["available"]
    assert_equal "new-mosque.localhost", response.parsed_body["host"]
  end

  test "default languages follow the country" do
    post "/nl/signup", params: valid_params(country: "BE", subdomain: "moskee-gent")
    assert_equal %w[nl fr], Account.find_by!(subdomain: "moskee-gent").languages
  end

  test "signup stores the khutbah language" do
    post "/en/signup", params: valid_params(source_language: "sq", subdomain: "xhamia-wien")
    assert_equal "sq", Account.find_by!(subdomain: "xhamia-wien").source_language
  end

  test "suggests a subdomain from the mosque name" do
    assert_equal "dzemat-nurnberg", Signup.suggest_subdomain("Džemat Nürnberg")
  end
end
