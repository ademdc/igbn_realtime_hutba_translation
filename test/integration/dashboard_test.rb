require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup do
    host! "demo.localhost"
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
  end

  test "shows trial, usage and QR codes" do
    get "/dashboard"
    assert_response :success
    assert_select "[role=meter][aria-valuemax='180']"
    assert_select ".qr-item", accounts(:demo).languages.size
    assert_select "#tv a[href='http://demo.localhost/tv/nl']"
  end

  test "after the trial the dashboard shows the free plan" do
    accounts(:demo).update!(languages: %w[nl de])
    accounts(:demo).update!(trial_ends_at: 1.day.ago)
    get "/dashboard"
    assert_response :success
    assert_select "[role=meter][aria-valuemax=?]", Account::FREE_MONTHLY_MINUTES.to_s
    assert_select "#plan-title + .stat__value", Regexp.union(I18n.available_locales.map { |locale| I18n.t("app.dashboard.plan.free", locale: locale) })
    assert_select ".qr-item", 1

    host! "demo.localhost"
    get "/"
    assert_response :success
  end

  test "the language switcher overrides the language saved at signup" do
    users(:demo_owner).update!(locale: "en")
    get "/dashboard", params: { locale: "bs" }
    assert_select "html[lang=bs]"
    assert_equal "bs", users(:demo_owner).reload.locale

    get "/dashboard"
    assert_select "html[lang=bs]"
  end

  test "owner changes languages within the limit" do
    patch "/dashboard/account", params: { section: "languages", account: { languages: ["", "de", "nl", "fr"] } }
    assert_redirected_to "http://demo.localhost/dashboard#languages"
    assert_equal %w[de nl fr], accounts(:demo).reload.languages
  end

  test "languages beyond the plan are rejected" do
    patch "/dashboard/account", params: { account: { languages: %w[de nl fr en] } }
    assert_response :unprocessable_entity
    assert_equal %w[nl], accounts(:demo).reload.languages
  end

  test "extra language add-ons raise the limit" do
    accounts(:demo).update!(extra_languages: 1)
    patch "/dashboard/account", params: { account: { languages: %w[de nl fr en] } }
    assert_equal 4, accounts(:demo).reload.languages.size
  end

  test "owner sets the speaker PIN" do
    patch "/dashboard/account", params: { account: { speaker_pin: "4711" } }
    assert accounts(:demo).reload.authenticate_speaker_pin("4711")

    patch "/dashboard/account", params: { account: { speaker_pin: "12ab" } }
    assert_response :unprocessable_entity
  end

  test "owner changes the khutbah language" do
    patch "/dashboard/account", params: { account: { source_language: "tr" } }
    assert_equal "tr", accounts(:demo).reload.source_language

    patch "/dashboard/account", params: { account: { source_language: "xx" } }
    assert_response :unprocessable_entity
  end

  test "owners with the domain add-on can change their domain" do
    accounts(:demo).update!(custom_domain_enabled: true)
    assert_enqueued_with(job: CustomDomainSetupJob) do
      patch "/dashboard/account", params: { section: "domain", account: { requested_custom_domain: "hutba.mosque-website.com" } }
    end
    assert_equal "hutba.mosque-website.com", accounts(:demo).reload.requested_custom_domain

    accounts(:demo).update!(custom_domain_status: "pending_dns", custom_domain_registered: "hutba.mosque-website.com",
                            custom_domain_target: "x.fly.dev")
    get "/dashboard"
    assert_select ".dns-record code", "x.fly.dev"
  end

  test "owners without the add-on cannot set a domain" do
    patch "/dashboard/account", params: { account: { requested_custom_domain: "hutba.mosque-website.com" } }
    assert_nil accounts(:demo).reload.requested_custom_domain
  end

  test "QR code downloads" do
    get "/dashboard/qr/nl.png"
    assert_equal "image/png", response.media_type
    get "/dashboard/qr/nl.svg"
    assert_equal "image/svg+xml", response.media_type
    get "/dashboard/qr/de.png"
    assert_response :not_found
  end

  test "printable poster" do
    get "/dashboard/poster"
    assert_response :success
    assert_select ".code", accounts(:demo).languages.size
  end

  test "speakers cannot change settings" do
    delete "/logout"
    post "/login", params: { email: "imam@demo.test", password: "password1234" }
    patch "/dashboard/account", params: { account: { name: "Hacked" } }
    assert_response :forbidden
    get "/dashboard/poster"
    assert_response :forbidden
  end
end
