class MarketingController < ApplicationController
  LOCALES = %w[de en fr nl bs tr].freeze

  layout "marketing"
  around_action :switch_locale, except: :locale_redirect

  def locale_redirect
    redirect_to marketing_path(locale: preferred_locale)
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

  def preferred_locale
    accepted = request.headers["Accept-Language"].to_s.scan(/([a-z]{2})(?:-[A-Za-z]{2})?(?:;q=([\d.]+))?/)
      .sort_by { |_, q| -(q || 1).to_f }
      .map(&:first)
    # Croatian/Serbian speakers read the Bosnian site best
    accepted = accepted.map { |code| %w[hr sr].include?(code) ? "bs" : code }
    (accepted & LOCALES).first || "de"
  end
end
