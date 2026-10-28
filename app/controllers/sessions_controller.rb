class SessionsController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  layout "app"

  def new
    redirect_to after_sign_in_path if current_user
  end

  def create
    user = Current.account.users.authenticate_by(email: params[:email], password: params[:password])

    if user
      sign_in(user)
      redirect_to after_sign_in_path
    else
      flash.now[:alert] = t("app.sessions.invalid")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    sign_out
    redirect_to login_path, notice: t("app.sessions.signed_out")
  end

  private

  def after_sign_in_path
    current_user.owner? ? dashboard_path : root_path
  end
end
