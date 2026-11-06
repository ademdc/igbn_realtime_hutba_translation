class AccountMailer < ApplicationMailer
  def welcome
    @user = params[:user]
    @account = @user.account
    mail to: @user.email, subject: t("mailers.welcome.subject", account: @account.name)
  end

  def reminder
    @user = params[:user]
    @account = @user.account
    @kind = params[:kind]
    @days_left = params[:days_left]
    @deadline = params[:deadline]
    mail to: @user.email, subject: t("mailers.reminder.#{@kind}.subject", account: @account.name, count: @days_left)
  end

  def custom_domain_dns
    @user = params[:user]
    @account = @user.account
    mail to: @user.email, subject: t("mailers.custom_domain_dns.subject", domain: @account.custom_domain_registered)
  end

  def custom_domain_live
    @user = params[:user]
    @account = @user.account
    mail to: @user.email, subject: t("mailers.custom_domain_live.subject", domain: @account.custom_domain)
  end

  # Bank details and reference for a transfer the owner just asked for
  def bank_transfer
    @payment = params[:payment]
    @user = params[:user]
    @account = @payment.account
    mail to: @user.email, subject: t("mailers.bank_transfer.subject", account: @account.name, reference: @payment.reference)
  end

  def login_links
    @accounts = params[:users].map(&:account)
    mail to: params[:email], subject: t("mailers.login_links.subject")
  end
end
