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

  def login_links
    @accounts = params[:users].map(&:account)
    mail to: params[:email], subject: t("mailers.login_links.subject")
  end
end
