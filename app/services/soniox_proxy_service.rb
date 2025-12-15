require 'faye/websocket'
require 'json'
require 'eventmachine'

class SonioxProxyService
  SONIOX_WS_URL = 'wss://stt-rt.soniox.com/transcribe-websocket'

  # Map language names to Soniox language codes
  LANGUAGE_CODES = {
    'german' => 'de',
    'english' => 'en'
  }.freeze

  @@connections = {}
  @@audio_buffers = {}
  @@em_thread = nil
  @@language_mutex = Mutex.new
  REDIS_ACTIVE_LANGUAGES_KEY = 'soniox:active_languages'

  class << self
    def start_event_machine
      return if @@em_thread && @@em_thread.alive?

      @@em_thread = Thread.new do
        EM.run do
          Rails.logger.info "EventMachine started for Soniox connections"
        end
      end

      sleep 0.1 until EM.reactor_running?
    end

    def get_or_create_connections(session_id)
      start_event_machine

      # Create one connection per active language
      active_langs = get_active_languages_from_redis
      connections = {}

      active_langs.each do |lang|
        lang_code = LANGUAGE_CODES[lang]
        next unless lang_code

        connection_key = "#{session_id}_#{lang}"

        unless @@connections[connection_key]
          Rails.logger.info "Creating Soniox connection for session: #{session_id}, language: #{lang}"
          @@audio_buffers[connection_key] = []
          @@connections[connection_key] = connect_to_soniox(session_id, lang, lang_code)
        end

        connections[lang] = @@connections[connection_key]
      end

      connections
    end

    def process_audio(audio_data, session_id, channel = nil)
      connections = get_or_create_connections(session_id)

      # Convert array of integers to binary string (16-bit signed little-endian)
      if audio_data.is_a?(Array)
        binary_data = audio_data.pack('s<*')

        # Send audio to ALL language connections for this session
        connections.each do |lang, connection|
          connection_key = "#{session_id}_#{lang}"

          EM.next_tick do
            state = connection&.ready_state
            if connection && state == Faye::WebSocket::API::OPEN
              connection.send(binary_data)
            else
              # Buffer audio data if connection is not ready yet
              buffer_size = @@audio_buffers[connection_key]&.size || 0
              Rails.logger.warn "Buffering audio for #{lang} (state: #{state}, buffer: #{buffer_size} chunks)"
              @@audio_buffers[connection_key] ||= []
              @@audio_buffers[connection_key] << binary_data
            end
          end
        end
      end
    end

    def close_connection(session_id)
      # Close all language connections for this session
      @@connections.keys.select { |key| key.start_with?("#{session_id}_") }.each do |connection_key|
        @@connections[connection_key]&.close
        @@connections.delete(connection_key)
        @@audio_buffers.delete(connection_key)
      end
    end

    def restart_connection(session_id)
      # Restart all language connections for this session
      Rails.logger.info "Restarting Soniox connections for session: #{session_id}"
      close_connection(session_id)
      get_or_create_connections(session_id)
    end

    def update_active_languages(languages)
      old_languages = get_active_languages_from_redis

      # Store in Redis so all processes can see it
      redis = Redis.new(
        url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" },
        ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      )
      redis.set(REDIS_ACTIVE_LANGUAGES_KEY, languages.to_json)
      redis.close

      Rails.logger.info "Updated active languages in Redis: #{languages.inspect}"

      # If languages changed and there are active connections, restart them
      if old_languages.sort != languages.sort && @@connections.any?
        Rails.logger.info "Active languages changed, restarting Soniox connections..."
        @@connections.keys.each do |session_id|
          restart_connection(session_id)
        end
      end
    end

    def active_language_codes
      languages = get_active_languages_from_redis
      codes = languages.map { |lang| LANGUAGE_CODES[lang] }.compact
      Rails.logger.info "Active language codes from Redis: #{codes.inspect} (from languages: #{languages.inspect})"
      codes
    end

    def get_active_languages_from_redis
      redis = Redis.new(
        url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" },
        ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
      )
      languages_json = redis.get(REDIS_ACTIVE_LANGUAGES_KEY)
      redis.close

      if languages_json
        JSON.parse(languages_json)
      else
        []
      end
    rescue => e
      Rails.logger.error "Error reading active languages from Redis: #{e.message}"
      []
    end

    private

    def connect_to_soniox(session_id, language_name, language_code)
      api_key = ENV['SONIOX_API_KEY']
      raise "SONIOX_API_KEY not configured" unless api_key

      connection_key = "#{session_id}_#{language_name}"
      ws_container = { ws: nil }

      EM.next_tick do
        ws = Faye::WebSocket::Client.new(SONIOX_WS_URL)
        ws_container[:ws] = ws

        ws.on :open do |event|
          Rails.logger.info "✓ Connected to Soniox for session: #{session_id}, language: #{language_name}"

          # Build configuration for Bosnian to target language
          config = {
            api_key: api_key,
            audio_format: "pcm_s16le",
            sample_rate: 16000,
            num_channels: 1,
            include_nonfinal: true,
            model: 'stt-rt-v3',
            translation: {
              type: "one_way",
              target_language: language_code
            }
          }

          config_json = JSON.generate(config)
          Rails.logger.info "Sending config for #{language_name}: #{config_json}"
          ws.send(config_json)
          Rails.logger.info "✓ Sent configuration to Soniox for #{language_name}"

          # Flush buffered audio data
          if @@audio_buffers[connection_key]&.any?
            Rails.logger.info "Flushing #{@@audio_buffers[connection_key].size} buffered audio chunks for #{language_name}"
            @@audio_buffers[connection_key].each do |binary_data|
              ws.send(binary_data)
            end
            @@audio_buffers[connection_key].clear
          end
        end

        ws.on :message do |event|
          begin
            result = JSON.parse(event.data)
            Rails.logger.info "Soniox response: #{result.inspect}"

            # Process tokens if present
            if result['tokens']&.any?
              # Broadcast translations to language-specific channels
              translations = extract_translations_by_language(result)
              translations.each do |lang_code, text|
                if text.present?
                  # Find the language name from the code
                  lang_name = LANGUAGE_CODES.key(lang_code)
                  if lang_name
                    Rails.logger.info "Broadcasting to #{lang_name}: #{text}"
                    ActionCable.server.broadcast(
                      "translation_#{lang_name}",
                      { text: text, timestamp: Time.current }
                    )
                  end
                end
              end

              # Send Bosnian original back to speaker
              original_text = extract_original(result)
              if original_text.present?
                Rails.logger.info "Sending original to speaker: #{original_text}"
                ActionCable.server.broadcast(
                  "translation_speaker_#{session_id}",
                  { original: original_text, timestamp: Time.current }
                )
              end
            end
          rescue JSON::ParserError => e
            Rails.logger.error "Failed to parse Soniox response: #{e.message}"
          rescue => e
            Rails.logger.error "Error processing Soniox message: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end

        ws.on :error do |event|
          Rails.logger.error "Soniox WebSocket error: #{event.message}"
        end

        ws.on :close do |event|
          Rails.logger.info "Soniox connection closed for session: #{session_id}, language: #{language_name}"
          @@connections.delete(connection_key)
          @@audio_buffers.delete(connection_key)
        end
      end

      # Wait for ws to be assigned (with timeout)
      timeout = 50  # 5 seconds
      while ws_container[:ws].nil? && timeout > 0
        sleep 0.1
        timeout -= 1
      end

      raise "Failed to create Soniox connection" if ws_container[:ws].nil?

      ws_container[:ws]
    end

    def extract_translations_by_language(result)
      tokens = result['tokens'] || []
      translations = {}

      # Extract translated tokens (only final translations)
      translated_tokens = tokens.select do |token|
        token['translation_status'] == 'translation' && token['is_final'] == true
      end

      # Group by target language
      translated_tokens.each do |token|
        lang_code = token['language']
        if lang_code
          translations[lang_code] ||= []
          translations[lang_code] << token['text']
        end
      end

      # Join tokens for each language
      translations.transform_values { |tokens| tokens.join('') }
    end

    def extract_original(result)
      tokens = result['tokens'] || []

      # Extract original tokens (only final)
      original_tokens = tokens.select do |token|
        token['translation_status'] == 'original' && token['is_final'] == true
      end

      original_tokens.map { |t| t['text'] }.join('')
    end
  end
end
