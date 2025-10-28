class CreateOrganizations < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :siret, limit: 14, null: false

      t.timestamps
    end

    add_index :organizations, :siret, unique: true, algorithm: :concurrently
  end
end
