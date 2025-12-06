require 'faye/websocket'
require 'json'
require 'eventmachine'

class SonioxProxyService
  SONIOX_WS_URL = 'wss://stt-rt.soniox.com/transcribe-websocket'

  @@connections = {}
  @@audio_buffers = {}
  @@channels = {}
  @@em_thread = nil

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

    def get_or_create_connection(session_id)
      start_event_machine

      @@connections[session_id] ||= begin
        Rails.logger.info "Creating new Soniox connection for session: #{session_id}"
        @@audio_buffers[session_id] = []
        connect_to_soniox(session_id)
      end
    end

    def process_audio(audio_data, session_id, channel = nil)
      connection = get_or_create_connection(session_id)

      # Store channel reference for this session
      @@channels[session_id] = channel if channel

      # Convert array of integers to binary string (16-bit signed little-endian)
      if audio_data.is_a?(Array)
        binary_data = audio_data.pack('s<*')

        EM.next_tick do
          state = connection&.ready_state
          if connection && state == Faye::WebSocket::API::OPEN
            connection.send(binary_data)
          else
            # Buffer audio data if connection is not ready yet
            buffer_size = @@audio_buffers[session_id]&.size || 0
            Rails.logger.warn "Buffering audio (state: #{state}, buffer: #{buffer_size} chunks)"
            @@audio_buffers[session_id] ||= []
            @@audio_buffers[session_id] << binary_data
          end
        end
      end
    end

    def close_connection(session_id)
      if @@connections[session_id]
        @@connections[session_id].close
        @@connections.delete(session_id)
        @@audio_buffers.delete(session_id)
        @@channels.delete(session_id)
      end
    end

    private

    def connect_to_soniox(session_id)
      api_key = ENV['SONIOX_API_KEY']
      raise "SONIOX_API_KEY not configured" unless api_key

      ws_container = { ws: nil }

      EM.next_tick do
        ws = Faye::WebSocket::Client.new(SONIOX_WS_URL)
        ws_container[:ws] = ws

        ws.on :open do |event|
          Rails.logger.info "✓ Connected to Soniox for session: #{session_id}"

          # Send configuration for Bosnian to German translation
          config = {
            api_key: api_key,
            audio_format: "pcm_s16le",
            sample_rate: 16000,
            num_channels: 1,
            include_nonfinal: true,
            model: 'stt-rt-v3',
            translation: {
              type: "one_way",
              target_language: "de"
            }
          }

          config_json = JSON.generate(config)
          Rails.logger.info "Sending config: #{config_json}"
          ws.send(config_json)
          Rails.logger.info "✓ Sent configuration to Soniox"

          # Flush buffered audio data
          if @@audio_buffers[session_id]&.any?
            Rails.logger.info "Flushing #{@@audio_buffers[session_id].size} buffered audio chunks"
            @@audio_buffers[session_id].each do |binary_data|
              ws.send(binary_data)
            end
            @@audio_buffers[session_id].clear
          end
        end

        ws.on :message do |event|
          begin
            result = JSON.parse(event.data)
            Rails.logger.info "Soniox response: #{result.inspect}"

            # Process tokens if present
            if result['tokens']&.any?
              # Broadcast German translations to all listeners
              translation_text = extract_translation(result)
              if translation_text.present?
                Rails.logger.info "Broadcasting translation: #{translation_text}"
                ActionCable.server.broadcast(
                  "translation_german",
                  { text: translation_text, timestamp: Time.current }
                )
              end

              # Send Bosnian original back to speaker
              original_text = extract_original(result)
              if original_text.present? && @@channels[session_id]
                Rails.logger.info "Sending original to speaker: #{original_text}"
                @@channels[session_id].transmit({
                  original: original_text,
                  timestamp: Time.current
                })
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
          Rails.logger.info "Soniox connection closed for session: #{session_id}"
          @@connections.delete(session_id)
          @@audio_buffers.delete(session_id)
          @@channels.delete(session_id)
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

    def extract_translation(result)
      tokens = result['tokens'] || []

      # Extract translated tokens (only final translations)
      translated_tokens = tokens.select do |token|
        token['translation_status'] == 'translation' && token['is_final'] == true
      end

      translated_tokens.map { |t| t['text'] }.join('')
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
