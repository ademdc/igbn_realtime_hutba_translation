module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :connection_uuid, :account

    def connect
      self.account = Account.for_host(request.host) || reject_unauthorized_connection
      self.connection_uuid = SecureRandom.uuid
    end

    def speaker?
      rails_session["speaker_account_id"] == account.id
    end

    private

    def rails_session
      cookies.encrypted[Rails.application.config.session_options[:key]] || {}
    end
  end
end
