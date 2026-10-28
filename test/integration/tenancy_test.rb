require "test_helper"

class TenancyTest < ActionDispatch::IntegrationTest
  test "listener index shows only the account's languages" do
    host! "igbd-nuernberg.localhost"
    get "/listener"
    assert_response :success
    assert_select "a[href='/de']"
    assert_select "a[href='/en']"
    assert_select "a[href='/nl']", count: 0
  end

  test "listener index skips the picker when there is one language" do
    host! "demo.localhost"
    get "/listener"
    assert_redirected_to "http://demo.localhost/nl"
  end

  test "language page by ISO code" do
    host! "igbd-nuernberg.localhost"
    get "/de"
    assert_response :success
    assert_select "#translationFeed[data-language='de']"
  end

  test "language not offered by account redirects to picker" do
    host! "demo.localhost"
    get "/de"
    assert_redirected_to "/listener"
  end

  test "legacy full-name routes redirect to ISO codes" do
    host! "igbd-nuernberg.localhost"
    get "/german"
    assert_redirected_to "http://igbd-nuernberg.localhost/de"
    get "/deutsch"
    assert_redirected_to "http://igbd-nuernberg.localhost/de"
  end

  test "unknown subdomain returns 404" do
    host! "nope.localhost"
    get "/listener"
    assert_response :not_found
  end

  test "speaker PIN only works for its own account" do
    host! "demo.localhost"
    post "/speaker/authenticate", params: { pin: "1234" }
    assert_response :unprocessable_entity

    post "/speaker/authenticate", params: { pin: "9999" }
    assert_redirected_to "http://demo.localhost/"
    get "/"
    assert_response :success
  end

  test "TV screen shows one column per language, at most three" do
    accounts(:igbd).update!(languages: %w[de en fr nl], extra_languages: 1)
    host! "igbd-nuernberg.localhost"

    get "/tv"
    assert_response :success
    assert_select ".tv__column", 3
    assert_select "[data-translation-feed][data-language=de]"
    assert_select ".tv__scan svg"

    get "/tv/en"
    assert_select ".tv__column", 1
    assert_select "[data-translation-feed][data-language=en]"
  end

  test "TV screen for a language the mosque doesn't offer falls back to all" do
    host! "demo.localhost"
    get "/tv/de"
    assert_redirected_to "http://demo.localhost/tv"
  end
end
