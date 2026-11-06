module MarketingHelper
  # The current page in each language, keyed by locale. Pages whose URL differs
  # per language (blog articles) set @alternates.
  def marketing_alternates
    @alternates || MarketingController::LOCALES.index_with { |locale| url_for(locale: locale, only_path: true) }
  end
end
