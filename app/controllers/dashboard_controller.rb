class DashboardController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"
  before_action :require_owner

  def show
    @account = Current.account
    @dashboard = DashboardPresenter.new(@account)
  end
end
