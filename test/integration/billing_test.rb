require "test_helper"

class BillingTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  KEY = "test-merchant-key"

  setup do
    @env = ENV.to_h.slice("MONRI_MERCHANT_KEY", "MONRI_AUTHENTICITY_TOKEN")
    ENV["MONRI_MERCHANT_KEY"] = KEY
    ENV["MONRI_AUTHENTICITY_TOKEN"] = "test-authenticity-token"
    host! "demo.localhost"
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
  end

  teardown do
    %w[MONRI_MERCHANT_KEY MONRI_AUTHENTICITY_TOKEN].each { |k| ENV[k] = @env[k] }
  end

  def billing_details
    { billing_name: "Džemat Demo e.V.", billing_address: "Hauptstr. 1", billing_zip: "90402",
      billing_city: "Nürnberg", billing_phone: "+49 911 0000", billing_email: "kasse@demo.test", country: "DE" }
  end

  test "billing page" do
    get "/dashboard/billing"
    assert_response :success
  end

  test "checkout creates a pending yearly payment and posts a signed form to Monri" do
    post "/dashboard/billing/checkout", params: { kind: "subscription", extra_languages: 1, account: billing_details }
    assert_response :success

    payment = accounts(:demo).payments.sole
    assert_equal "pending", payment.status
    assert_equal (2000 + 500) * 12, payment.amount_cents

    assert_select "form[action='https://ipgtest.monri.com/v2/form']"
    assert_select "input[name=amount][value='30000']"
    assert_select "input[name=currency][value=EUR]"
    expected = Digest::SHA512.hexdigest("#{KEY}#{payment.order_number}30000EUR")
    assert_select "input[name=digest][value=?]", expected
    assert_equal "Hauptstr. 1", accounts(:demo).reload.billing_address
  end

  test "checkout requires billing details" do
    post "/dashboard/billing/checkout", params: { kind: "subscription", extra_languages: 0, account: { billing_name: "" } }
    assert_response :unprocessable_entity
    assert_equal 0, Payment.count
  end

  test "signed success redirect approves the payment" do
    payment = Payment.subscription_for(accounts(:demo), user: users(:demo_owner), extra_languages: 0)
    payment.save!

    url = "http://demo.localhost/dashboard/billing/success?order_number=#{payment.order_number}&amount=#{payment.amount_cents}&currency=EUR&response_code=0000"
    digest = Digest::SHA512.hexdigest("#{KEY}#{url}")
    get "#{URI(url).request_uri}&digest=#{digest}"

    assert_redirected_to "http://demo.localhost/dashboard/billing"
    account = accounts(:demo).reload
    assert payment.reload.approved?
    assert_equal "active", account.status
    assert_in_delta 1.year.from_now, account.paid_until, 1.minute
  end

  test "tampered success redirect does not approve" do
    payment = Payment.subscription_for(accounts(:demo), user: users(:demo_owner), extra_languages: 0)
    payment.save!

    get "/dashboard/billing/success?order_number=#{payment.order_number}&amount=#{payment.amount_cents}&response_code=0000&digest=forged"
    assert payment.reload.pending?
    assert_equal "trialing", accounts(:demo).reload.status
  end

  test "signed callback approves once, unsigned callback is rejected" do
    payment = Payment.subscription_for(accounts(:demo), user: users(:demo_owner), extra_languages: 2)
    payment.save!
    body = { order_number: payment.order_number, status: "approved", amount: payment.amount_cents, currency: "EUR" }.to_json

    host! "localhost"
    post "/monri/callback", params: body, headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "WP3-callback wrong" }
    assert_response :unauthorized
    assert payment.reload.pending?

    signature = "WP3-callback #{Digest::SHA512.hexdigest("#{KEY}#{body}")}"
    2.times do
      post "/monri/callback", params: body, headers: { "CONTENT_TYPE" => "application/json", "Authorization" => signature }
      assert_response :ok
    end
    assert payment.reload.approved?
    assert_equal 2, accounts(:demo).reload.extra_languages
  end

  test "callback with a different amount declines" do
    payment = Payment.subscription_for(accounts(:demo), user: users(:demo_owner), extra_languages: 0)
    payment.save!
    body = { order_number: payment.order_number, status: "approved", amount: 1, currency: "EUR" }.to_json

    post "/monri/callback", params: body, headers: { "CONTENT_TYPE" => "application/json",
      "Authorization" => "WP3-callback #{Digest::SHA512.hexdigest("#{KEY}#{body}")}" }
    assert_equal "declined", payment.reload.status
  end

  test "add-on languages are prorated to the paid period" do
    accounts(:demo).update!(status: "active", paid_until: 4.months.from_now - 1.day)
    post "/dashboard/billing/checkout", params: { kind: "addon", extra_languages: 2, account: billing_details }
    payment = accounts(:demo).payments.sole
    assert_equal "addon", payment.kind
    assert_equal 2 * 500 * 4, payment.amount_cents

    payment.approve!
    assert_equal 2, accounts(:demo).reload.extra_languages
  end

  test "booking an own domain with the yearly plan" do
    post "/dashboard/billing/checkout", params: { kind: "subscription", extra_languages: 0, custom_domain: "1",
                                                  account: billing_details.merge(requested_custom_domain: "Hutba.Mosque-Website.com") }
    payment = accounts(:demo).payments.sole
    assert payment.custom_domain?
    assert_equal (2000 + 500) * 12, payment.amount_cents
    assert_equal "hutba.mosque-website.com", accounts(:demo).reload.requested_custom_domain

    assert_enqueued_email_with AdminMailer, :custom_domain_requested, params: { account: accounts(:demo) } do
      payment.approve!
    end
    account = accounts(:demo).reload
    assert account.custom_domain_enabled?
    assert_nil account.custom_domain, "goes live only after DNS is set up"
  end

  test "own domain needs the domain name" do
    post "/dashboard/billing/checkout", params: { kind: "subscription", extra_languages: 0, custom_domain: "1", account: billing_details }
    assert_response :unprocessable_entity
    assert_equal 0, Payment.count
  end

  test "own domain added mid-year is prorated" do
    accounts(:demo).update!(status: "active", paid_until: 3.months.from_now - 1.day)
    post "/dashboard/billing/checkout", params: { kind: "addon", extra_languages: 0, custom_domain: "1",
                                                  account: billing_details.merge(requested_custom_domain: "hutba.mosque-website.com") }
    payment = accounts(:demo).payments.sole
    assert_equal 500 * 3, payment.amount_cents
  end

  test "renewal keeps a booked domain" do
    accounts(:demo).update!(custom_domain_enabled: true)
    post "/dashboard/billing/checkout", params: { kind: "subscription", extra_languages: 0, account: billing_details }
    assert_equal (2000 + 500) * 12, accounts(:demo).payments.sole.amount_cents
  end

  test "expired paid year blocks streaming" do
    account = accounts(:demo)
    account.update!(status: "active", paid_until: 1.day.ago)
    assert account.payment_due?
    assert_not account.can_stream?
  end
end
