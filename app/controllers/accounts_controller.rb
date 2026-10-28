# Mosque settings edited from the dashboard: name, listener languages, speaker PIN.
class AccountsController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"
  before_action :require_owner

  def update
    @account = Current.account

    if @account.update(account_params)
      CustomDomainSetupJob.perform_later(@account) if @account.saved_change_to_requested_custom_domain?
      redirect_to dashboard_path(anchor: params[:section]), notice: t("app.accounts.saved")
    else
      @dashboard = DashboardPresenter.new(@account)
      render "dashboard/show", status: :unprocessable_entity
    end
  end

  private

  def account_params
    allowed = [:name, :speaker_pin, :source_language, { languages: [] }]
    allowed << :requested_custom_domain if Current.account.custom_domain_enabled?
    permitted = params.require(:account).permit(*allowed)
    # Unchecking every box submits only the hidden blank value
    permitted[:languages] = permitted[:languages].compact_blank if permitted.key?(:languages)
    permitted
  end
end
