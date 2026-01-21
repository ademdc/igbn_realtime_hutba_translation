class CreateListenerConnections < ActiveRecord::Migration[7.1]
  def change
    create_table :listener_connections do |t|
      t.string :session_id, null: false
      t.string :language, null: false
      t.datetime :connected_at, null: false
      t.datetime :disconnected_at
      t.integer :duration_seconds

      t.timestamps
    end

    add_index :listener_connections, :session_id
    add_index :listener_connections, :language
    add_index :listener_connections, :connected_at
  end
end
