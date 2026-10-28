class ListenerController < ApplicationController
  include AccountScoped

  layout "listener"

  def index
    # Language selection page
    @languages = Current.account.languages.index_with { |code| Language.info(code) }
    # Nothing to choose: go straight to the only language
    redirect_to listener_language_path(language: @languages.keys.first) if @languages.size == 1
  end

  # Up to three languages side by side on a TV; more would be unreadable from the back of the hall
  def tv
    languages = params[:language] ? [params[:language]] : Current.account.languages
    @tv_languages = languages.select { |code| Current.account.offers_language?(code) }.first(3)
    return redirect_to tv_path if @tv_languages.empty?

    @language = @tv_languages.first
  end

  def show
    @language = params[:language]
    @language_info = Language.info(@language)

    unless Current.account.offers_language?(@language)
      redirect_to listener_path, alert: "Language not supported"
    end
  end
end
