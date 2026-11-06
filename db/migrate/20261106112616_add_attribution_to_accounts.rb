class AddAttributionToAccounts < ActiveRecord::Migration[7.1]
  def change
    # How a mosque found Hutba: its own answer at signup, plus the campaign link or
    # site it first arrived from
    add_column :accounts, :heard_from, :string
    add_column :accounts, :utm_source, :string
    add_column :accounts, :utm_medium, :string
    add_column :accounts, :utm_campaign, :string
    add_column :accounts, :referrer_host, :string
  end
end
