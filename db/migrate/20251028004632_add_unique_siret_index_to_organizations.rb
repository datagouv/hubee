class AddUniqueSiretIndexToOrganizations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :organizations, :siret, unique: true, algorithm: :concurrently
  end
end
