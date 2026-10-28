class CreateAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :custom_domain
      t.string :languages, array: true, null: false, default: ["de"]
      t.string :speaker_pin_digest
      t.string :status, null: false, default: "trialing"
      t.datetime :trial_ends_at
      t.integer :weekly_minutes_limit, null: false, default: 180

      t.timestamps
    end

    add_index :accounts, :subdomain, unique: true
    add_index :accounts, :custom_domain, unique: true
  end
end
