class AddBranchCodeToOrganizationLinks < ActiveRecord::Migration[8.1]
  # Un SIRET peut porter plusieurs organisations : l'identité complète est le couple
  # (siret, branch_code). `null: false` sans défaut ni reprise — aucune valeur ne peut
  # être inventée pour une ligne existante, mieux vaut un échec franc (spec D4).
  def change
    add_column :organization_links, :branch_code, :string, null: false

    # `unique: true` pour qu'un rollback recrée l'index d'origine, pas un index affaibli.
    remove_index :organization_links, :siret, unique: true
    add_index :organization_links, [:siret, :branch_code], unique: true
  end
end
