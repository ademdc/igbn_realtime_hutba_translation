# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if Rails.env.development?
  # Open http://igbd-nuernberg.localhost:3000 and http://demo.localhost:3000 (speaker PIN 1234)
  Account.find_or_create_by!(subdomain: "igbd-nuernberg") do |account|
    account.name = "IGBD Nürnberg"
    account.status = "active"
    account.languages = %w[de en]
    account.speaker_pin = "1234"
  end

  Account.find_or_create_by!(subdomain: "demo") do |account|
    account.name = "Demo Džemat"
    account.languages = %w[de nl fr]
    account.speaker_pin = "1234"
  end
end

if Rails.env.development?
  # Dev logins (password "password1234"):
  #   owner@igbd.test   -> http://igbd-nuernberg.localhost:3010/login
  #   owner@demo.test   -> http://demo.localhost:3010/login
  #   imam@demo.test    -> speaker only
  #   admin@hutba.test  -> http://localhost:3010/admin/login
  { "igbd-nuernberg" => [["owner@igbd.test", "Vorstand IGBD", "owner"]],
    "demo" => [["owner@demo.test", "Emir Demo", "owner"], ["imam@demo.test", "Imam Demo", "speaker"]] }.each do |subdomain, users|
    account = Account.find_by!(subdomain: subdomain)
    users.each do |email, name, role|
      account.users.find_or_create_by!(email: email) do |user|
        user.name = name
        user.role = role
        user.password = "password1234"
        user.confirmed_at = Time.current
      end
    end
  end

  User.find_or_create_by!(email: "admin@hutba.test", admin: true, account_id: nil) do |user|
    user.name = "Super Admin"
    user.password = "password1234"
    user.confirmed_at = Time.current
  end
end
