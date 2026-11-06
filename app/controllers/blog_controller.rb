class BlogController < MarketingController
  def index
    @posts = BlogPost.for_locale(I18n.locale)
  end

  def show
    @post = BlogPost.find(I18n.locale, params[:slug]) or raise ActionController::RoutingError, "Not found"
    # Language links point to the translated article, or to the blog index if there is none
    @alternates = MarketingController::LOCALES.index_with do |locale|
      translation = @post.translations[locale]
      translation ? blog_post_path(locale: locale, slug: translation.slug) : blog_path(locale: locale)
    end
    @hreflang_locales = @post.translations.keys
  end
end
