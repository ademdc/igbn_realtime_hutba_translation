# Notes for the people running Hutba, sent to CONTACT_EMAIL
class AdminMailer < ApplicationMailer
  def bank_transfer_requested
    @payment = params[:payment]
    @account = @payment.account
    mail to: Rails.configuration.x.contact_email,
         subject: "Bank transfer expected: #{@payment.reference}, #{@account.name}"
  end
end
