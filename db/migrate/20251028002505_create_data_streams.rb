class CreateDataStreams < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :data_streams, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.references :owner_organization, type: :uuid, null: false,
        foreign_key: {to_table: :organizations},
        index: false
      t.integer :retention_days, default: 365

      t.timestamps
    end

    add_index :data_streams, :owner_organization_id, algorithm: :concurrently
  end
end
