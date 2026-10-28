class SpeakerController < ApplicationController
  include AccountScoped
  before_action :authenticate_speaker, only: [:index]

  def index
    # Speaker page with recording controls
  end

  def login
    # Show PIN login form
  end

  def authenticate
    if params[:pin].present? && Current.account.authenticate_speaker_pin(params[:pin])
      reset_session
      session[:speaker_account_id] = Current.account.id
      redirect_to root_path, notice: "Successfully authenticated"
    else
      flash.now[:alert] = "Invalid PIN. Please try again."
      @pin_error = true
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session[:speaker_account_id] = nil
    redirect_to speaker_login_path, notice: "Logged out"
  end

  private

  def authenticate_speaker
    unless session[:speaker_account_id] == Current.account.id
      redirect_to speaker_login_path
    end
  end
end
