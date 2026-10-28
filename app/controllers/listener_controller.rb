class ListenerController < ApplicationController
  include AccountScoped

  def index
    # Language selection page
    @languages = Current.account.languages.index_with { |code| Language.info(code) }
  end

  def show
    @language = params[:language]
    @language_info = Language.info(@language)

    unless Current.account.offers_language?(@language)
      redirect_to listener_path, alert: "Language not supported"
    end
  end
end
