class AddSignupFieldsToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :country, :string
    add_column :accounts, :city, :string
    # Base plan includes 3 languages; each paid add-on adds one
    add_column :accounts, :extra_languages, :integer, null: false, default: 0
  end
end
