# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_01_21_120748) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "listener_connections", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "language", null: false
    t.datetime "connected_at", null: false
    t.datetime "disconnected_at"
    t.integer "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["connected_at"], name: "index_listener_connections_on_connected_at"
    t.index ["language"], name: "index_listener_connections_on_language"
    t.index ["session_id"], name: "index_listener_connections_on_session_id"
  end

  create_table "speaker_sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "duration_seconds"
    t.integer "word_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_speaker_sessions_on_session_id"
    t.index ["started_at"], name: "index_speaker_sessions_on_started_at"
  end

end
