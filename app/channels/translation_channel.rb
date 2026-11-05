class TranslationChannel < ApplicationCable::Channel
  # Track active subscribers per account and language: { account_id => { language => Set[session_id] } }
  @@language_subscribers = Hash.new { |h, account_id| h[account_id] = Hash.new { |h2, lang| h2[lang] = Set.new } }
  @@language_mutex = Mutex.new

  class << self
    def active_languages(account_id)
      @@language_mutex.synchronize do
        @@language_subscribers[account_id].select { |_, subs| subs.any? }.keys
      end
    end

    def subscriber_count(account_id, language)
      @@language_mutex.synchronize do
        @@language_subscribers[account_id][language].size
      end
    end

    def listener_stats(account_id)
      @@language_mutex.synchronize do
        stats = {}
        total = 0
        @@language_subscribers[account_id].each do |lang, subs|
          count = subs.size
          stats[lang] = count if count > 0
          total += count
        end
        { total: total, by_language: stats }
      end
    end

    def broadcast_listener_stats(account_id)
      ActionCable.server.broadcast(listener_stats_stream(account_id), listener_stats(account_id))
    end

    def translation_stream(account_id, language)
      "translation:#{account_id}:#{language}"
    end

    def speaker_stream(account_id, session_id)
      "translation_speaker:#{account_id}:#{session_id}"
    end

    def listener_stats_stream(account_id)
      "listener_stats:#{account_id}"
    end
  end

  def subscribed
    @account = connection.account
    @session_id = connection.connection_uuid
    @language = params[:language] || 'de'
    @is_speaker = params[:is_speaker] || false

    Rails.logger.info "TranslationChannel subscribed - account: #{@account.subdomain}, session: #{@session_id}, language: #{@language}, speaker: #{@is_speaker}"

    if @is_speaker
      return reject unless connection.speaker?

      unless @account.can_stream?
        transmit({ error: "streaming_unavailable", weekly_limit_reached: @account.weekly_limit_reached? })
        return reject
      end

      # Speakers get the original transcription
      stream_from self.class.speaker_stream(@account.id, @session_id)
      # Speakers also get listener stats updates
      stream_from self.class.listener_stats_stream(@account.id)

      # Send current listener stats immediately
      transmit({ listener_stats: self.class.listener_stats(@account.id) })

      # Track speaker session in database
      @speaker_session = @account.speaker_sessions.start_session(@session_id)
    else
      return reject unless @account.offers_language?(@language)

      # Listeners get translations for their chosen language
      stream_from self.class.translation_stream(@account.id, @language)

      # Track this subscriber
      @@language_mutex.synchronize do
        @@language_subscribers[@account.id][@language] << @session_id
        Rails.logger.info "Active languages for #{@account.subdomain}: #{@@language_subscribers[@account.id].keys} (#{@@language_subscribers[@account.id][@language].size} #{@language} listeners)"
      end

      # Track listener connection in database
      @listener_connection = @account.listener_connections.start_connection(@session_id, @language)

      # Notify Soniox service of active languages
      SonioxProxyService.update_active_languages(@account.id, self.class.active_languages(@account.id))

      # Broadcast updated listener stats to speakers
      self.class.broadcast_listener_stats(@account.id)
    end
  end

  def unsubscribed
    if @speaker_session
      # Audio chunks still queued after this must not open a new Soniox connection
      @stopped = true
      # Close Soniox connection when speaker disconnects
      SonioxProxyService.close_connection(@account.id, @session_id)
      Rails.logger.info "Closed Soniox connection for session: #{@session_id}"

      # End speaker session in database
      @speaker_session.end_session(word_count: @word_count || 0)
    elsif @listener_connection
      # Remove listener from tracking
      @@language_mutex.synchronize do
        subscribers = @@language_subscribers[@account.id]
        subscribers[@language].delete(@session_id)
        Rails.logger.info "Listener unsubscribed from #{@language}. Remaining: #{subscribers[@language].size}"

        # Clean up empty language sets
        subscribers.delete(@language) if subscribers[@language].empty?
        @@language_subscribers.delete(@account.id) if subscribers.empty?
      end

      # End listener connection in database
      @listener_connection.end_connection

      # Notify Soniox service of updated active languages
      SonioxProxyService.update_active_languages(@account.id, self.class.active_languages(@account.id))

      # Broadcast updated listener stats to speakers
      self.class.broadcast_listener_stats(@account.id)
    end
  end

  def receive(data)
    # Only speakers can send audio data
    if @speaker_session && !@stopped && data['audio']
      SonioxProxyService.process_audio(data['audio'], @account.id, @session_id)
    end
  end
end
