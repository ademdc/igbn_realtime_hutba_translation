class AddCustomDomainAutomation < ActiveRecord::Migration[7.1]
  def change
    # pending_dns: registered with Heroku, waiting for the mosque's DNS + certificate
    # live: custom_domain is serving; failed: Heroku couldn't register it
    add_column :accounts, :custom_domain_status, :string
    add_column :accounts, :custom_domain_target, :string      # Heroku DNS target for the CNAME
    add_column :accounts, :custom_domain_registered, :string  # hostname currently registered with Heroku
    add_column :accounts, :custom_domain_checked_at, :datetime
  end
end
