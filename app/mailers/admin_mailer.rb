# Notifications to the Hutba team (CONTACT_EMAIL).
class AdminMailer < ApplicationMailer
  def custom_domain_requested
    @account = params[:account]
    mail to: Rails.configuration.x.contact_email, subject: "Custom domain paid: #{@account.requested_custom_domain} (#{@account.name})"
  end
end
