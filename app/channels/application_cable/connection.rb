module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :connection_uuid

    def connect
      self.connection_uuid = SecureRandom.uuid
    end
  end
end
