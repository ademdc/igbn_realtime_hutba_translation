class AddAccountToSessionsAndConnections < ActiveRecord::Migration[7.1]
  # Existing data belongs to the original single-tenant deployment (IGBD Nürnberg).
  DEFAULT_SUBDOMAIN = "igbd-nuernberg"

  class MigrationAccount < ActiveRecord::Base
    self.table_name = "accounts"
  end

  def up
    add_reference :speaker_sessions, :account, foreign_key: true
    add_reference :listener_connections, :account, foreign_key: true

    account = MigrationAccount.find_or_create_by!(subdomain: DEFAULT_SUBDOMAIN) do |a|
      a.name = "IGBD Nürnberg"
      a.languages = ["de"]
      a.status = "active"
      # Carry over the PIN the deployment already uses
      a.speaker_pin_digest = BCrypt::Password.create(ENV["SPEAKER_PIN"]) if ENV["SPEAKER_PIN"].present?
    end

    execute "UPDATE speaker_sessions SET account_id = #{account.id} WHERE account_id IS NULL"
    execute "UPDATE listener_connections SET account_id = #{account.id} WHERE account_id IS NULL"

    # Old rows stored full language names; listeners now use ISO codes.
    execute "UPDATE listener_connections SET language = 'de' WHERE language = 'german'"
    execute "UPDATE listener_connections SET language = 'en' WHERE language = 'english'"

    change_column_null :speaker_sessions, :account_id, false
    change_column_null :listener_connections, :account_id, false
  end

  def down
    execute "UPDATE listener_connections SET language = 'german' WHERE language = 'de'"
    execute "UPDATE listener_connections SET language = 'english' WHERE language = 'en'"
    remove_reference :listener_connections, :account
    remove_reference :speaker_sessions, :account
  end
end
