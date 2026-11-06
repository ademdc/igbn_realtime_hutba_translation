require "test_helper"

class MarketingTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  test "apex root opens the German site whatever the browser language" do
    get "/", headers: { "Accept-Language" => "nl-NL,nl;q=0.9,en;q=0.8" }
    assert_redirected_to "http://localhost/de"
  end

  test "landing page renders in every locale" do
    MarketingController::LOCALES.each do |locale|
      get "/#{locale}"
      assert_response :success
      assert_select "html[lang=?]", locale
      assert_select "h1", I18n.t("marketing.hero.title", locale: locale)
      assert_select "link[rel=alternate][hreflang]", MarketingController::LOCALES.size + 1 # plus x-default
      assert_select ".tv-mock"
    end
  end

  test "legal pages render" do
    get "/de/impressum"
    assert_response :success
    get "/en/privacy"
    assert_response :success
  end

  test "www also serves the marketing site" do
    host! "www.localhost"
    get "/en"
    assert_response :success
    assert_select ".hero"
  end

  test "mosque subdomains keep listener routes" do
    host! "demo.localhost"
    get "/nl"
    assert_select "#translationFeed"
  end
end
