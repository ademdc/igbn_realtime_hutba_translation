class AddPaymentMethodToPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :payment_method, :string, null: false, default: "card"
    add_index :payments, [:payment_method, :status]
  end
end
