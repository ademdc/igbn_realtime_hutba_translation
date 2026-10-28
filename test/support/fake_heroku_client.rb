# Stands in for CustomDomains::HerokuClient in tests.
class FakeHerokuClient
  cattr_accessor :domains, default: {}
  cattr_accessor :removed, default: []
  cattr_accessor :acm_status, default: "pending"

  def self.configured? = true

  def self.reset!
    self.domains = {}
    self.removed = []
    self.acm_status = "pending"
  end

  def add(hostname)
    domains[hostname] = "#{hostname.tr(".", "-")}.herokudns.com"
    info(hostname)
  end

  def info(hostname)
    CustomDomains::HerokuClient::Domain.new(hostname: hostname, target: domains.fetch(hostname), acm_status: acm_status)
  end

  def remove(hostname)
    removed << hostname
    domains.delete(hostname)
  end
end
