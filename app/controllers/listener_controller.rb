class ListenerController < ApplicationController
  SUPPORTED_LANGUAGES = {
    'german' => { name: 'Deutsch', code: 'de', flag: '🇩🇪' },
    'english' => { name: 'English', code: 'en', flag: '🇬🇧' }
  }.freeze

  def index
    # Language selection page
    @languages = SUPPORTED_LANGUAGES
  end

  def show
    @language = params[:language]
    @language_info = SUPPORTED_LANGUAGES[@language]

    unless @language_info
      redirect_to listener_path, alert: "Language not supported"
    end
  end

  # Keep old german action for backward compatibility
  def german
    redirect_to german_path
  end
end
