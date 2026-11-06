class MarketingController < ApplicationController
  LOCALES = %w[de en fr nl bs tr].freeze

  layout "marketing"
  around_action :switch_locale, except: :locale_redirect

  def locale_redirect
    # The site opens in German whatever the browser language; visitors switch in the header
    redirect_to marketing_path(locale: "de")
  end

  def index
    # Default demo language: the visitor's own, if mosques can offer it
    @demo_language = Language.supported?(params[:locale]) ? params[:locale] : "de"
  end

  def imprint
  end

  def privacy
  end

  def terms
  end

  private

  def switch_locale(&action)
    I18n.with_locale(params[:locale], &action)
  end
end
