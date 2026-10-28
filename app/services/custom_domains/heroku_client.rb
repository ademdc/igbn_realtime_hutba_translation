require "net/http"

# Registers mosque domains with the Heroku app through the Platform API, so
# Heroku's Automated Certificate Management (ACM) issues their certificates.
#
# ENV: HEROKU_API_TOKEN (heroku authorizations:create), HEROKU_APP_NAME
module CustomDomains
  class HerokuClient
    class Error < StandardError; end

    Domain = Struct.new(:hostname, :target, :acm_status, keyword_init: true) do
      def certificate_issued?
        acm_status.to_s.match?(/cert issued/i)
      end

      def failed?
        acm_status.to_s.match?(/\Afailed\z/i)
      end
    end

    def self.configured?
      ENV["HEROKU_API_TOKEN"].present? && ENV["HEROKU_APP_NAME"].present?
    end

    def add(hostname)
      to_domain(request(Net::HTTP::Post, "/apps/#{app}/domains", { hostname: hostname, sni_endpoint: nil }))
    rescue Error => e
      # Already registered (e.g. a retried job): just read it back
      raise unless e.message.include?("already")
      info(hostname)
    end

    def info(hostname)
      to_domain(request(Net::HTTP::Get, "/apps/#{app}/domains/#{hostname}"))
    end

    def remove(hostname)
      request(Net::HTTP::Delete, "/apps/#{app}/domains/#{hostname}")
    rescue Error => e
      raise unless e.message.include?("not_found") || e.message.include?("Couldn't find")
    end

    private

    def app
      ENV.fetch("HEROKU_APP_NAME")
    end

    def to_domain(json)
      Domain.new(hostname: json["hostname"], target: json["cname"], acm_status: json["acm_status"])
    end

    def request(klass, path, body = nil)
      uri = URI("https://api.heroku.com#{path}")
      req = klass.new(uri)
      req["Accept"] = "application/vnd.heroku+json; version=3"
      req["Authorization"] = "Bearer #{ENV.fetch("HEROKU_API_TOKEN")}"
      req["Content-Type"] = "application/json"
      req.body = body.to_json if body

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
      json = response.body.present? ? JSON.parse(response.body) : {}
      raise Error, "#{response.code} #{json["id"]}: #{json["message"]}" unless response.is_a?(Net::HTTPSuccess)
      json
    end
  end
end
