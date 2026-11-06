require "test_helper"

class BankTransferTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  include ActiveJob::TestHelper

  def billing_details
    { billing_name: "Džemat Demo e.V.", billing_address: "Hauptstr. 1", billing_zip: "90402",
      billing_city: "Nürnberg", billing_phone: "+49 911 0000", billing_email: "kasse@demo.test", country: "DE" }
  end

  def request_transfer
    host! "demo.localhost"
    post "/login", params: { email: "owner@demo.test", password: "password1234" }
    perform_enqueued_jobs do
      post "/dashboard/billing/checkout", params: { kind: "subscription", extra_languages: 0, payment_method: "bank_transfer", account: billing_details }
    end
    accounts(:demo).payments.awaiting_transfer.last
  end

  test "owner gets bank details and a reference, admins are told" do
    payment = request_transfer

    assert_redirected_to "http://demo.localhost/dashboard/billing#transfer"
    assert_equal 24_000, payment.amount_cents
    assert_equal "pending", accounts(:demo).payments.last.status

    owner_mail, admin_mail = ActionMailer::Base.deliveries.last(2)
    assert_includes owner_mail.to, "owner@demo.test"
    assert_includes owner_mail.text_part.body.to_s, "BA39 1610 0002 8865 0089"
    assert_includes owner_mail.text_part.body.to_s, payment.reference
    assert_equal ["info@everline.io"], admin_mail.to

    follow_redirect!
    assert_select "#transfer code", /#{payment.reference}/
  end

  test "works without card payments set up" do
    assert_not Monri::Gateway.configured?
    assert request_transfer
  end

  test "a new request replaces the open one" do
    first = request_transfer
    second = request_transfer
    assert_equal "declined", first.reload.status
    assert_equal [second], accounts(:demo).payments.awaiting_transfer.to_a
  end

  test "admin marks the transfer as paid and the plan starts" do
    payment = request_transfer
    accounts(:demo).update!(trial_ends_at: 1.day.ago)
    assert accounts(:demo).free_plan?

    host! "localhost"
    post "/admin/login", params: { email: "admin@hutba.test", password: "password1234" }
    get "/admin/dashboard"
    assert_select "td", /#{payment.reference}/

    post "/admin/payments/#{payment.id}/confirm"
    assert payment.reload.approved?
    account = accounts(:demo).reload
    assert_equal "active", account.status
    assert_not account.free_plan?
    assert_in_delta 1.year.from_now, account.paid_until, 1.minute
  end

  test "admin can cancel a transfer that never came" do
    payment = request_transfer
    host! "localhost"
    post "/admin/login", params: { email: "admin@hutba.test", password: "password1234" }
    post "/admin/payments/#{payment.id}/cancel"
    assert_equal "declined", payment.reload.status
    assert_equal "trialing", accounts(:demo).reload.status
  end
end
