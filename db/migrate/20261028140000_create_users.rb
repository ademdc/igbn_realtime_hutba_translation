class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      # Super admins have no account
      t.references :account, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "owner"
      t.boolean :admin, null: false, default: false
      t.string :locale
      t.datetime :confirmed_at
      t.datetime :last_login_at

      t.timestamps
    end

    add_index :users, [:account_id, :email], unique: true
    add_index :users, :email, unique: true, where: "admin", name: "index_users_on_email_for_admins"
  end
end
