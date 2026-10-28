class AddSourceLanguageToAccounts < ActiveRecord::Migration[7.1]
  def change
    # Language the imam speaks; existing mosques were all Bosnian
    add_column :accounts, :source_language, :string, null: false, default: "bs"
  end
end
