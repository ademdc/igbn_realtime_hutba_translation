class CreatePayments < ActiveRecord::Migration[7.1]
  def change
    create_table :payments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :kind, null: false                  # subscription | addon
      t.string :order_number, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "EUR"
      t.string :status, null: false, default: "pending"  # pending | approved | declined
      t.integer :extra_languages, null: false, default: 0 # add-on languages bought with this payment
      t.datetime :period_start
      t.datetime :period_end
      t.datetime :approved_at
      t.jsonb :gateway_response, null: false, default: {}

      t.timestamps
    end
    add_index :payments, :order_number, unique: true

    change_table :accounts do |t|
      t.datetime :paid_until
      t.string :billing_name
      t.string :billing_address
      t.string :billing_zip
      t.string :billing_city
      t.string :billing_phone
      t.string :billing_email
      t.string :last_reminder
    end
  end
end
