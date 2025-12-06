class TranslationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "translation_german"
    # Use connection identifier as session ID
    @session_id = connection.connection_identifier
    Rails.logger.info "TranslationChannel subscribed with session: #{@session_id}"
  end

  def unsubscribed
    # Close Soniox connection when channel is unsubscribed
    if @session_id
      SonioxProxyService.close_connection(@session_id)
      Rails.logger.info "Closed Soniox connection for session: #{@session_id}"
    end
  end

  def receive(data)
    # Forward audio data to Soniox proxy with session ID and channel reference
    if data['audio']
      SonioxProxyService.process_audio(data['audio'], @session_id || connection.connection_identifier, self)
    end
  end
end
