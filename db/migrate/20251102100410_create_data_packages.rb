class CreateDataPackages < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :data_packages, id: :uuid do |t|
      t.references :data_stream, type: :uuid, null: false,
        foreign_key: {on_delete: :restrict},
        index: false
      t.references :sender_organization, type: :uuid, null: false,
        foreign_key: {to_table: :organizations},
        index: false
      t.string :state, null: false, default: "draft"
      t.string :title
      t.timestamp :sent_at
      t.timestamp :acknowledged_at
      t.timestamps
    end

    add_index :data_packages, :data_stream_id, algorithm: :concurrently
    add_index :data_packages, :sender_organization_id, algorithm: :concurrently
    add_index :data_packages, :state, algorithm: :concurrently
    add_index :data_packages, [:data_stream_id, :state], algorithm: :concurrently

    add_check_constraint :data_packages,
      "state IN ('draft', 'transmitted', 'acknowledged')",
      name: "state_check"
  end
end
