# Invited users choose their password here. Same flow as a password reset,
# with a longer-lived token.
class InvitationsController < PasswordResetsController
  def update
    if @user.update(password_params.merge(confirmed_at: Time.current))
      sign_in(@user)
      redirect_to @user.owner? ? dashboard_path : root_path, notice: t("app.invitations.accepted", account: Current.account.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def token_purpose
    :invitation
  end
end
