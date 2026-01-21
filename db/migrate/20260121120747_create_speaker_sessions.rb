class CreateSpeakerSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :speaker_sessions do |t|
      t.string :session_id, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :duration_seconds
      t.integer :word_count, default: 0

      t.timestamps
    end

    add_index :speaker_sessions, :session_id
    add_index :speaker_sessions, :started_at
  end
end
