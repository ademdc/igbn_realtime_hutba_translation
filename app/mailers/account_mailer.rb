class AccountMailer < ApplicationMailer
  def login_links
    @accounts = params[:users].map(&:account)
    mail to: params[:email], subject: t("mailers.login_links.subject")
  end
end
