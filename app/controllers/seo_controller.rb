# robots.txt and sitemap.xml. Only the marketing site is meant to be found in search;
# mosque subdomains and custom domains send a noindex header (see ApplicationController).
class SeoController < ApplicationController
  PAGES = %w[marketing signup marketing_imprint marketing_privacy marketing_terms].freeze

  def robots
    lines = ["User-agent: *"]
    if AppDomain.marketing_host?(request.host)
      lines += ["Disallow: /*/login", "", "Sitemap: #{AppDomain.marketing_url("/sitemap.xml")}"]
    else
      lines << "Allow: /"
    end
    render plain: lines.join("\n") + "\n"
  end

  def sitemap
    @pages = PAGES
    @locales = MarketingController::LOCALES
  end
end
