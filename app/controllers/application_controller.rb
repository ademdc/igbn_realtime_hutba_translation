class ApplicationController < ActionController::Base
  before_action :keep_mosque_pages_out_of_search

  private

  # Speaker panels, listener pages and dashboards live on mosque hosts and should not show up in Google
  def keep_mosque_pages_out_of_search
    response.headers["X-Robots-Tag"] = "noindex, nofollow" unless AppDomain.marketing_host?(request.host)
  end
end
