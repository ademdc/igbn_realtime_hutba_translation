require "test_helper"

class CustomDomainsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    FakeDomainClient.reset!
    CustomDomains.client_class = "FakeDomainClient"
    @account = accounts(:demo)
    @account.update!(custom_domain_enabled: true, requested_custom_domain: "hutba.mosque-website.com")
  end

  teardown { CustomDomains.client_class = nil }

  test "setup registers the domain with the host and emails the DNS record" do
    assert_enqueued_emails 1 do
      CustomDomains.setup(@account)
    end

    @account.reload
    assert_equal "pending_dns", @account.custom_domain_status
    assert_equal "hutba-app.fly.dev", @account.custom_domain_target
    assert_nil @account.custom_domain, "not live before the certificate exists"
  end

  test "check switches the domain live once the certificate is issued" do
    CustomDomains.setup(@account)

    CustomDomains.check_pending
    assert_equal "pending_dns", @account.reload.custom_domain_status

    FakeDomainClient.issued = true
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
    FakeDomainClient.issued = true
    CustomDomains.check_pending

    FakeDomainClient.issued = false
    @account.reload.update!(requested_custom_domain: "hutba.new-site.org")
    CustomDomains.setup(@account)
    assert_equal "hutba.mosque-website.com", @account.reload.custom_domain
    assert_empty FakeDomainClient.removed

    FakeDomainClient.issued = true
    CustomDomains.check_pending
    assert_equal "hutba.new-site.org", @account.reload.custom_domain
    assert_equal ["hutba.mosque-website.com"], FakeDomainClient.removed
  end

  test "nothing happens without the add-on" do
    @account.update!(custom_domain_enabled: false)
    CustomDomains.setup(@account)
    assert_empty FakeDomainClient.domains
  end
end
