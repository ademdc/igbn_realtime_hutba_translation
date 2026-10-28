# Team management for mosque owners: invite imams/speakers and other owners.
class UsersController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"
  before_action :require_owner

  def index
    @users = Current.account.users.order(:created_at)
    @user = User.new(role: "speaker")
  end

  def create
    @user = User.invite(account: Current.account, name: user_params[:name], email: user_params[:email], role: user_params[:role])

    if @user.persisted?
      UserMailer.with(user: @user, inviter: current_user, locale: I18n.locale.to_s).invitation.deliver_later
      redirect_to users_path, notice: t("app.users.invited", email: @user.email)
    else
      @users = Current.account.users.order(:created_at)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    user = Current.account.users.find(params[:id])

    if user == current_user
      redirect_to users_path, alert: t("app.users.cannot_remove_self")
    else
      user.destroy!
      redirect_to users_path, notice: t("app.users.removed", name: user.name)
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
