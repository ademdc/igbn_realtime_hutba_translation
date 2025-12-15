class TranslationChannel < ApplicationCable::Channel
  # Track active subscribers per language
  @@language_subscribers = Hash.new { |h, k| h[k] = Set.new }
  @@language_mutex = Mutex.new

  class << self
    def active_languages
      @@language_mutex.synchronize do
        @@language_subscribers.select { |_, subs| subs.any? }.keys
      end
    end

    def subscriber_count(language)
      @@language_mutex.synchronize do
        @@language_subscribers[language].size
      end
    end
  end

  def subscribed
    @session_id = connection.connection_identifier
    @language = params[:language] || 'german'
    @is_speaker = params[:is_speaker] || false

    Rails.logger.info "TranslationChannel subscribed - session: #{@session_id}, language: #{@language}, speaker: #{@is_speaker}"

    if @is_speaker
      # Speakers get the original transcription
      stream_from "translation_speaker_#{@session_id}"
    else
      # Listeners get translations for their chosen language
      stream_from "translation_#{@language}"

      # Track this subscriber
      @@language_mutex.synchronize do
        @@language_subscribers[@language] << @session_id
        Rails.logger.info "Active languages: #{@@language_subscribers.keys} (#{@@language_subscribers[@language].size} #{@language} listeners)"
      end

      # Notify Soniox service of active languages
      SonioxProxyService.update_active_languages(self.class.active_languages)
    end
  end

  def unsubscribed
    if @is_speaker && @session_id
      # Close Soniox connection when speaker disconnects
      SonioxProxyService.close_connection(@session_id)
      Rails.logger.info "Closed Soniox connection for session: #{@session_id}"
    elsif @language
      # Remove listener from tracking
      @@language_mutex.synchronize do
        @@language_subscribers[@language].delete(@session_id)
        Rails.logger.info "Listener unsubscribed from #{@language}. Remaining: #{@@language_subscribers[@language].size}"

        # Clean up empty language sets
        @@language_subscribers.delete(@language) if @@language_subscribers[@language].empty?
      end

      # Notify Soniox service of updated active languages
      SonioxProxyService.update_active_languages(self.class.active_languages)
    end
  end

  def receive(data)
    # Only speakers can send audio data
    if @is_speaker && data['audio']
      SonioxProxyService.process_audio(data['audio'], @session_id || connection.connection_identifier, self)
    end
  end
end
