require "net/http"

# Requests Let's Encrypt certificates for mosque domains through the Fly.io
# Machines API (https://docs.fly.io/api/machines). The mosque points a CNAME at
# the app, and Fly validates and renews the certificate on its own.
#
# ENV: FLY_API_TOKEN (fly tokens create deploy). Fly sets FLY_APP_NAME itself.
module CustomDomains
  class FlyClient
    class Error < CustomDomains::Error; end

    API = "https://api.machines.dev/v1"

    def self.configured?
      ENV["FLY_API_TOKEN"].present? && ENV["FLY_APP_NAME"].present?
    end

    def add(hostname)
      to_domain(request(Net::HTTP::Post, "/apps/#{app}/certificates/acme", { hostname: hostname }))
    rescue Error => e
      # Already requested (e.g. a retried job): read it back, or report the original error
      begin
        info(hostname)
      rescue Error
        raise e
      end
    end

    # Asks Fly to re-check DNS, so a fresh CNAME is picked up on the next poll
    def info(hostname)
      to_domain(request(Net::HTTP::Post, "/apps/#{app}/certificates/#{hostname}/check"))
    end

    def remove(hostname)
      request(Net::HTTP::Delete, "/apps/#{app}/certificates/#{hostname}")
    rescue Error => e
      raise unless e.message.start_with?("404")
    end

    private

    def app
      ENV.fetch("FLY_APP_NAME")
    end

    def to_domain(json)
      issued = Array(json["certificates"]).any? { |cert| cert["status"] == "active" } ||
        json["status"].to_s.casecmp?("ready")
      Domain.new(hostname: json["hostname"], target: json.dig("dns_requirements", "cname").presence || "#{app}.fly.dev",
                 issued: issued)
    end

    # `fly tokens create` prints "FlyV1 …" tokens, older personal tokens are plain bearer tokens
    def authorization
      token = ENV.fetch("FLY_API_TOKEN")
      token.start_with?("FlyV1 ") ? token : "Bearer #{token}"
    end

    def request(klass, path, body = nil)
      uri = URI("#{API}#{path}")
      req = klass.new(uri)
      req["Authorization"] = authorization
      req["Content-Type"] = "application/json"
      req.body = body.to_json if body

      response = perform(uri, req)
      json = response.body.present? ? (JSON.parse(response.body) rescue { "error" => response.body }) : {}
      raise Error, "#{response.code} #{json["error"] || json["message"]}" unless response.is_a?(Net::HTTPSuccess)
      json
    end

    def perform(uri, req)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
    end
  end
end
