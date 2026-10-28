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

ActiveRecord::Schema[7.1].define(version: 2026_10_28_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "subdomain", null: false
    t.string "custom_domain"
    t.string "languages", default: ["de"], null: false, array: true
    t.string "speaker_pin_digest"
    t.string "status", default: "trialing", null: false
    t.datetime "trial_ends_at"
    t.integer "weekly_minutes_limit", default: 180, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_domain"], name: "index_accounts_on_custom_domain", unique: true
    t.index ["subdomain"], name: "index_accounts_on_subdomain", unique: true
  end

  create_table "listener_connections", force: :cascade do |t|
    t.string "session_id", null: false
    t.string "language", null: false
    t.datetime "connected_at", null: false
    t.datetime "disconnected_at"
    t.integer "duration_seconds"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_listener_connections_on_account_id"
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
    t.bigint "account_id", null: false
    t.index ["account_id"], name: "index_speaker_sessions_on_account_id"
    t.index ["session_id"], name: "index_speaker_sessions_on_session_id"
    t.index ["started_at"], name: "index_speaker_sessions_on_started_at"
  end

  create_table "users", force: :cascade do |t|
    t.bigint "account_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "role", default: "owner", null: false
    t.boolean "admin", default: false, null: false
    t.string "locale"
    t.datetime "confirmed_at"
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "email"], name: "index_users_on_account_id_and_email", unique: true
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email_for_admins", unique: true, where: "admin"
  end

  add_foreign_key "listener_connections", "accounts"
  add_foreign_key "speaker_sessions", "accounts"
  add_foreign_key "users", "accounts"
end
