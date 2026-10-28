class AddCustomDomainBilling < ActiveRecord::Migration[7.1]
  class MigrationAccount < ActiveRecord::Base
    self.table_name = "accounts"
  end

  def up
    # Own domain is a paid add-on; requested_custom_domain is what the mosque asked for
    # until we've set up DNS and the certificate and move it to custom_domain.
    add_column :accounts, :custom_domain_enabled, :boolean, null: false, default: false
    add_column :accounts, :requested_custom_domain, :string
    add_column :payments, :custom_domain, :boolean, null: false, default: false

    # The original Nürnberg tenant already runs on its own domain; keep it, free of charge.
    nuernberg = MigrationAccount.find_by(subdomain: "igbd-nuernberg")
    if nuernberg && !MigrationAccount.where(custom_domain: "hutba.igbd-nuernberg.de").where.not(id: nuernberg.id).exists?
      nuernberg.update_columns(custom_domain: "hutba.igbd-nuernberg.de", custom_domain_enabled: true)
    end
    MigrationAccount.where.not(custom_domain: nil).update_all(custom_domain_enabled: true)
  end

  def down
    remove_column :payments, :custom_domain
    remove_column :accounts, :requested_custom_domain
    remove_column :accounts, :custom_domain_enabled
  end
end
