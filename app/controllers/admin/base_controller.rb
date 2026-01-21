module Admin
  class BaseController < ApplicationController
    layout 'admin'
    before_action :authenticate_admin

    private

    def authenticate_admin
      unless session[:admin_authenticated]
        redirect_to admin_login_path
      end
    end
  end
end
