require "test_helper"

class AdminAccountsTest < ActionDispatch::IntegrationTest
  setup do
    host! "localhost"
    post "/admin/login", params: { email: "admin@hutba.test", password: "password1234" }
  end

  test "overview shows KPIs" do
    accounts(:igbd).update!(extra_languages: 1)
    get "/admin/dashboard"
    assert_response :success
    assert_select ".kpi__value", text: "€25"
  end

  test "accounts list with search and status filter" do
    get "/admin/accounts"
    assert_response :success
    assert_select "tbody tr", 2

    get "/admin/accounts", params: { q: "demo" }
    assert_select "tbody tr", 1

    get "/admin/accounts", params: { status: "active" }
    assert_select "tbody tr td a", text: "IGBD Nürnberg"
    assert_select "tbody tr", 1
  end

  test "account detail and plan changes" do
    account = accounts(:demo)
    get "/admin/accounts/#{account.id}"
    assert_response :success

    patch "/admin/accounts/#{account.id}", params: { account: { status: "active", extra_languages: 2 } }
    assert_equal "active", account.reload.status
    assert_equal 5, account.language_limit
  end

  test "extend trial" do
    account = accounts(:demo)
    account.update!(trial_ends_at: 2.days.ago)
    post "/admin/accounts/#{account.id}/extend_trial", params: { days: 14 }
    assert_in_delta 14.days.from_now, account.reload.trial_ends_at, 1.minute
    assert_not account.trial_expired?
  end

  test "impersonate opens the owner's dashboard on the subdomain" do
    account = accounts(:demo)
    post "/admin/accounts/#{account.id}/impersonate"
    assert_match %r{\Ahttp://demo\.localhost/session/}, response.location

    host! "demo.localhost"
    get URI(response.location).path
    assert_redirected_to "http://demo.localhost/dashboard"
  end

  test "non-admins are kept out" do
    delete "/admin/logout"
    get "/admin/accounts"
    assert_redirected_to "http://localhost/admin/login"
  end
end
