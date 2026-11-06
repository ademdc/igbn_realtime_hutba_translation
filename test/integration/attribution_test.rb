require "test_helper"

class AttributionTest < ActionDispatch::IntegrationTest
  setup { host! "localhost" }

  def signup(overrides = {})
    post "/bs/signup", params: { signup: { mosque_name: "Džemat Ulm", subdomain: "dzemat-ulm", country: "DE",
      name: "Amir", email: "amir@example.com", password: "supersecret1", terms: "1" }.merge(overrides) }
    Account.find_by!(subdomain: "dzemat-ulm")
  end

  test "the campaign link of the first visit is saved on the new account" do
    get "/bs?utm_source=flyer&utm_medium=post&utm_campaign=igbd-2026"
    get "/de/blog?utm_source=google"   # later visits don't overwrite the first
    account = signup(heard_from: "flyer")

    assert_equal "flyer", account.heard_from
    assert_equal %w[flyer post igbd-2026], [account.utm_source, account.utm_medium, account.utm_campaign]
    assert_equal "Flyer or letter · flyer / post / igbd-2026", account.attribution_summary
  end

  test "an outside referring site is remembered, our own pages are not" do
    get "/de", headers: { "Referer" => "http://localhost/de/blog" }
    get "/de", headers: { "Referer" => "https://www.google.com/search?q=hutba" }
    assert_equal "www.google.com", signup.referrer_host
  end

  test "the question is optional and rejects unknown answers" do
    get "/de/signup"
    assert_select "select[name='signup[heard_from]'] option", Account::HEARD_FROM.size + 1

    assert_nil signup(heard_from: "").heard_from
    assert_not Account.new(heard_from: "tv").tap(&:validate).errors[:heard_from].empty?
  end

  test "admin sees where signups come from" do
    get "/bs?utm_source=flyer"
    signup(heard_from: "other_mosque")

    post "/admin/login", params: { email: "admin@hutba.test", password: "password1234" }
    get "/admin/dashboard"
    assert_select "td", "Another mosque"
    assert_select "td", "flyer"
  end
end
