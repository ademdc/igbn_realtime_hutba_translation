require "test_helper"

class CustomDomainsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    FakeHerokuClient.reset!
    CustomDomains.client_class = "FakeHerokuClient"
    @account = accounts(:demo)
    @account.update!(custom_domain_enabled: true, requested_custom_domain: "hutba.mosque-website.com")
  end

  teardown { CustomDomains.client_class = "CustomDomains::HerokuClient" }

  test "setup registers the domain with Heroku and emails the DNS record" do
    assert_enqueued_emails 1 do
      CustomDomains.setup(@account)
    end

    @account.reload
    assert_equal "pending_dns", @account.custom_domain_status
    assert_equal "hutba-mosque-website-com.herokudns.com", @account.custom_domain_target
    assert_nil @account.custom_domain, "not live before the certificate exists"
  end

  test "check switches the domain live once the certificate is issued" do
    CustomDomains.setup(@account)

    CustomDomains.check_pending
    assert_equal "pending_dns", @account.reload.custom_domain_status

    FakeHerokuClient.acm_status = "cert issued"
    assert_enqueued_emails 1 do
      CustomDomains.check_pending
    end
    @account.reload
    assert_equal "live", @account.custom_domain_status
    assert_equal "hutba.mosque-website.com", @account.custom_domain
    assert_equal @account, Account.for_host("hutba.mosque-website.com")
  end

  test "switching to another domain keeps the old one live until the new one is ready" do
    CustomDomains.setup(@account)
    FakeHerokuClient.acm_status = "cert issued"
    CustomDomains.check_pending

    FakeHerokuClient.acm_status = "pending"
    @account.reload.update!(requested_custom_domain: "hutba.new-site.org")
    CustomDomains.setup(@account)
    assert_equal "hutba.mosque-website.com", @account.reload.custom_domain
    assert_empty FakeHerokuClient.removed

    FakeHerokuClient.acm_status = "cert issued"
    CustomDomains.check_pending
    assert_equal "hutba.new-site.org", @account.reload.custom_domain
    assert_equal ["hutba.mosque-website.com"], FakeHerokuClient.removed
  end

  test "nothing happens without the add-on" do
    @account.update!(custom_domain_enabled: false)
    CustomDomains.setup(@account)
    assert_empty FakeHerokuClient.domains
  end
end
