class SpeakerController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale
  layout "app"
  before_action :authenticate_speaker, only: [:index]

  def index
    # Speaker page with recording controls
  end

  def login
    # Show PIN login form
  end

  def authenticate
    if params[:pin].present? && Current.account.authenticate_speaker_pin(params[:pin])
      locale = session[:locale]
      reset_session
      session[:locale] = locale
      session[:speaker_account_id] = Current.account.id
      redirect_to root_path
    else
      flash.now[:alert] = t("app.speaker.login.invalid")
      @pin_error = true
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    locale = session[:locale]
    reset_session
    session[:locale] = locale
    redirect_to speaker_login_path, notice: t("app.sessions.signed_out")
  end

  private

  def authenticate_speaker
    unless current_user || session[:speaker_account_id] == Current.account.id
      redirect_to speaker_login_path
    end
  end
end
