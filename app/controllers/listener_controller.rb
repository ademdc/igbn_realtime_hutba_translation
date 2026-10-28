class ListenerController < ApplicationController
  include AccountScoped

  layout "listener"

  def index
    # Language selection page
    @languages = Current.account.languages.index_with { |code| Language.info(code) }
    # Nothing to choose: go straight to the only language
    redirect_to listener_language_path(language: @languages.keys.first) if @languages.size == 1
  end

  def show
    @language = params[:language]
    @language_info = Language.info(@language)

    unless Current.account.offers_language?(@language)
      redirect_to listener_path, alert: "Language not supported"
    end
  end
end
