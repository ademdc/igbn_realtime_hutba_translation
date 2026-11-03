# Stands in for CustomDomains::FlyClient / HerokuClient in tests.
class FakeDomainClient
  cattr_accessor :domains, default: {}
  cattr_accessor :removed, default: []
  cattr_accessor :issued, default: false

  def self.configured? = true

  def self.reset!
    self.domains = {}
    self.removed = []
    self.issued = false
  end

  def add(hostname)
    domains[hostname] = "hutba-app.fly.dev"
    info(hostname)
  end

  def info(hostname)
    CustomDomains::Domain.new(hostname: hostname, target: domains.fetch(hostname), issued: issued)
  end

  def remove(hostname)
    removed << hostname
    domains.delete(hostname)
  end
end
