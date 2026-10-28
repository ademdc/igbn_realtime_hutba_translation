# Fully automatic own-domain setup:
#   1. setup: register the requested domain with Heroku and tell the mosque which CNAME to add
#   2. check (every 10 minutes): once Heroku has issued the certificate, switch the domain live
module CustomDomains
  mattr_accessor :client_class, default: "CustomDomains::HerokuClient"

  def self.client
    client_class.constantize.new
  end

  def self.configured?
    client_class.constantize.configured?
  end

  def self.setup(account)
    domain = account.requested_custom_domain
    return unless account.custom_domain_enabled? && domain.present?
    return if account.custom_domain == domain && account.custom_domain_status == "live"

    unless configured?
      Rails.logger.warn "Custom domain #{domain} for #{account.subdomain} not registered: Heroku API not configured"
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
  rescue HerokuClient::Error => e
    Rails.logger.error "Custom domain setup failed for #{account.subdomain}: #{e.message}"
    account.update_columns(custom_domain_status: "failed", custom_domain_checked_at: Time.current)
  end

  def self.check_pending
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
  rescue HerokuClient::Error => e
    Rails.logger.error "Custom domain check failed for #{account.subdomain}: #{e.message}"
  end
end
