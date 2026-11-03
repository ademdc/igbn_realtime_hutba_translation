# Fully automatic own-domain setup:
#   1. setup: register the requested domain with the host and tell the mosque which CNAME to add
#   2. check (every 10 minutes): once the host has issued the certificate, switch the domain live
#
# The same code runs on Fly.io and Heroku; the client is picked by where the app runs.
module CustomDomains
  class Error < StandardError; end

  # What both hosting clients return for a hostname
  Domain = Struct.new(:hostname, :target, :issued, keyword_init: true) do
    def certificate_issued?
      issued
    end
  end

  # Tests set this; otherwise Fly when running there (Fly sets FLY_APP_NAME), else Heroku
  mattr_accessor :client_class

  def self.client_class_name
    client_class || (ENV["FLY_APP_NAME"].present? ? "CustomDomains::FlyClient" : "CustomDomains::HerokuClient")
  end

  def self.client
    client_class_name.constantize.new
  end

  def self.configured?
    client_class_name.constantize.configured?
  end

  def self.setup(account)
    domain = account.requested_custom_domain
    return unless account.custom_domain_enabled? && domain.present?
    return if account.custom_domain == domain && account.custom_domain_status == "live"

    unless configured?
      Rails.logger.warn "Custom domain #{domain} for #{account.subdomain} not registered: #{client_class_name} not configured"
      return
    end

    # The mosque changed its mind: drop the previously registered hostname
    previous = account.custom_domain_registered
    client.remove(previous) if previous.present? && previous != domain && previous != account.custom_domain

    registered = client.add(domain)
    account.update!(custom_domain_registered: domain, custom_domain_target: registered.target,
                    custom_domain_status: "pending_dns", custom_domain_checked_at: Time.current)
    account.users.owners.each do |owner|
      AccountMailer.with(user: owner).custom_domain_dns.deliver_later
    end
  rescue Error => e
    Rails.logger.error "Custom domain setup failed for #{account.subdomain}: #{e.message}"
    account.update_columns(custom_domain_status: "failed", custom_domain_checked_at: Time.current)
  end

  def self.check_pending
    return unless configured?
    Account.where(custom_domain_status: "pending_dns").find_each { |account| check(account) }
  end

  def self.check(account)
    domain = client.info(account.custom_domain_registered)
    account.update_columns(custom_domain_checked_at: Time.current, custom_domain_target: domain.target)
    return unless domain.certificate_issued?

    previous_live = account.custom_domain
    account.update!(custom_domain: account.custom_domain_registered, custom_domain_status: "live")
    client.remove(previous_live) if previous_live.present? && previous_live != account.custom_domain
    account.users.owners.each do |owner|
      AccountMailer.with(user: owner).custom_domain_live.deliver_later
    end
  rescue Error => e
    Rails.logger.error "Custom domain check failed for #{account.subdomain}: #{e.message}"
  end
end
