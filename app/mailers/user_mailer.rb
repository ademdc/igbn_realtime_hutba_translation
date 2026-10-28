class UserMailer < ApplicationMailer
  def password_reset
    @user = params[:user]
    @account = @user.account
    @url = @account.url("/password_resets/#{@user.generate_token_for(:password_reset)}/edit")

    mail to: @user.email, subject: t("mailers.password_reset.subject", account: @account.name)
  end

  def invitation
    @user = params[:user]
    @inviter = params[:inviter]
    @account = @user.account
    @url = @account.url("/invitation/#{@user.generate_token_for(:invitation)}")

    mail to: @user.email, subject: t("mailers.invitation.subject", account: @account.name)
  end
end
