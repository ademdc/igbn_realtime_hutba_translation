class DashboardController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"
  before_action :require_owner

  def show
    @account = Current.account
  end
end
