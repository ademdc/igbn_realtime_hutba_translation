# The apex domain the product runs on (e.g. hutba.app). Mosques live on its
# subdomains; the apex and www serve the marketing site.
module AppDomain
  def self.host
    ENV.fetch("APP_DOMAIN", "localhost").downcase
  end

  def self.marketing_host?(host)
    host = host.to_s.downcase
    host == self.host || host == "www.#{self.host}"
  end

  # Routing constraint for the marketing site
  def self.matches?(request)
    marketing_host?(request.host)
  end
end
