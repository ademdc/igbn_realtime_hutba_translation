class SpeakerController < ApplicationController
  before_action :authenticate_speaker, only: [:index]

  def index
    # Speaker page with recording controls
  end

  def login
    # Show PIN login form
  end

  def authenticate
    if params[:pin].present? && params[:pin] == ENV['SPEAKER_PIN']
      session[:speaker_authenticated] = true
      redirect_to root_path, notice: "Successfully authenticated"
    else
      flash.now[:alert] = "Invalid PIN. Please try again."
      @pin_error = true
      render :login, status: :unprocessable_entity
    end
  end

  def logout
    session[:speaker_authenticated] = nil
    redirect_to speaker_login_path, notice: "Logged out"
  end

  private

  def authenticate_speaker
    unless session[:speaker_authenticated]
      redirect_to speaker_login_path
    end
  end
end
