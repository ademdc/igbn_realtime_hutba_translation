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

    def listener_stats
      @@language_mutex.synchronize do
        stats = {}
        total = 0
        @@language_subscribers.each do |lang, subs|
          count = subs.size
          stats[lang] = count if count > 0
          total += count
        end
        { total: total, by_language: stats }
      end
    end

    def broadcast_listener_stats
      stats = listener_stats
      ActionCable.server.broadcast("listener_stats", stats)
    end
  end

  def subscribed
    @session_id = connection.connection_uuid
    @language = params[:language] || 'german'
    @is_speaker = params[:is_speaker] || false

    Rails.logger.info "TranslationChannel subscribed - session: #{@session_id}, language: #{@language}, speaker: #{@is_speaker}"

    if @is_speaker
      # Speakers get the original transcription
      stream_from "translation_speaker_#{@session_id}"
      # Speakers also get listener stats updates
      stream_from "listener_stats"

      # Send current listener stats immediately
      transmit({ listener_stats: self.class.listener_stats })

      # Track speaker session in database
      @speaker_session = SpeakerSession.start_session(@session_id)
    else
      # Listeners get translations for their chosen language
      stream_from "translation_#{@language}"

      # Track this subscriber
      @@language_mutex.synchronize do
        @@language_subscribers[@language] << @session_id
        Rails.logger.info "Active languages: #{@@language_subscribers.keys} (#{@@language_subscribers[@language].size} #{@language} listeners)"
      end

      # Track listener connection in database
      @listener_connection = ListenerConnection.start_connection(@session_id, @language)

      # Notify Soniox service of active languages
      SonioxProxyService.update_active_languages(self.class.active_languages)

      # Broadcast updated listener stats to speakers
      self.class.broadcast_listener_stats
    end
  end

  def unsubscribed
    if @is_speaker && @session_id
      # Close Soniox connection when speaker disconnects
      SonioxProxyService.close_connection(@session_id)
      Rails.logger.info "Closed Soniox connection for session: #{@session_id}"

      # End speaker session in database
      @speaker_session&.end_session(word_count: @word_count || 0)
    elsif @language
      # Remove listener from tracking
      @@language_mutex.synchronize do
        @@language_subscribers[@language].delete(@session_id)
        Rails.logger.info "Listener unsubscribed from #{@language}. Remaining: #{@@language_subscribers[@language].size}"

        # Clean up empty language sets
        @@language_subscribers.delete(@language) if @@language_subscribers[@language].empty?
      end

      # End listener connection in database
      @listener_connection&.end_connection

      # Notify Soniox service of updated active languages
      SonioxProxyService.update_active_languages(self.class.active_languages)

      # Broadcast updated listener stats to speakers
      self.class.broadcast_listener_stats
    end
  end

  def receive(data)
    # Only speakers can send audio data
    if @is_speaker && data['audio']
      SonioxProxyService.process_audio(data['audio'], @session_id || connection.connection_uuid, self)
    end
  end
end
