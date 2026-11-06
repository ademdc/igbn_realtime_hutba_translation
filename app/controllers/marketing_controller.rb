class MarketingController < ApplicationController
  LOCALES = %w[de en fr nl bs tr].freeze

  layout "marketing"
  around_action :switch_locale, except: :locale_redirect
  before_action :remember_attribution

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

  # First visit only: the campaign link (?utm_source=flyer…) or the outside site the
  # visitor came from. Kept in the session cookie Rails already sets, until signup.
  def remember_attribution
    return if session[:attribution].present?

    utm = params.permit(:utm_source, :utm_medium, :utm_campaign).to_h.transform_values { |value| value.to_s.first(100) }
    referrer = URI.parse(request.referer.to_s).host rescue nil
    referrer = nil if referrer.blank? || referrer == request.host || referrer.end_with?(".#{AppDomain.host}")
    session[:attribution] = utm.merge("referrer_host" => referrer).compact_blank if utm.any? || referrer
  end

  def switch_locale(&action)
    I18n.with_locale(params[:locale], &action)
  end
end
