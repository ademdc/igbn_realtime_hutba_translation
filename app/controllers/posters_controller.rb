# Printable A4 poster with one QR code per language, for the mosque entrance.
class PostersController < ApplicationController
  include AccountScoped
  include Authentication
  include AppLocale

  before_action :require_owner

  def show
    @account = Current.account
    render layout: false
  end
end
