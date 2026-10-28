# Locale for the mosque-facing app (login, dashboard): the user's saved choice,
# then ?locale=, then the browser language.
module AppLocale
  extend ActiveSupport::Concern

  included do
    around_action :switch_app_locale
  end

  private

  def switch_app_locale(&action)
    session[:locale] = params[:locale] if MarketingController::LOCALES.include?(params[:locale])
    locale = current_user&.locale || session[:locale] || browser_locale
    I18n.with_locale(locale, &action)
  end

  def browser_locale
    accepted = request.headers["Accept-Language"].to_s.scan(/([a-z]{2})(?:-[A-Za-z]{2})?(?:;q=([\d.]+))?/)
      .sort_by { |_, q| -(q || 1).to_f }
      .map { |code, _| %w[hr sr].include?(code) ? "bs" : code }
    (accepted & MarketingController::LOCALES).first || "de"
  end
end
