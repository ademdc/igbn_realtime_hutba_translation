module Admin
  class SessionsController < ApplicationController
    layout 'admin'

    def new
      redirect_to admin_dashboard_path if session[:admin_authenticated]
    end

    def create
      if valid_credentials?
        session[:admin_authenticated] = true
        redirect_to admin_dashboard_path, notice: "Successfully logged in"
      else
        flash.now[:alert] = "Invalid username or password"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session[:admin_authenticated] = nil
      redirect_to admin_login_path, notice: "Logged out"
    end

    private

    def valid_credentials?
      params[:username].present? &&
        params[:password].present? &&
        params[:username] == ENV['ADMIN_USERNAME'] &&
        params[:password] == ENV['ADMIN_PASSWORD']
    end
  end
end
