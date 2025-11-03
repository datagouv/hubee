class CreateDataPackages < ActiveRecord::Migration[8.1]
  def up
    # Create PostgreSQL ENUM type for state (requires DDL transaction)
    create_enum "data_package_state", ["draft", "transmitted", "acknowledged"]

    create_table :data_packages, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :data_stream, type: :uuid, null: false,
        foreign_key: {on_delete: :restrict},
        index: false
      t.references :sender_organization, type: :uuid, null: false,
        foreign_key: {to_table: :organizations},
        index: false
      t.enum :state, enum_type: "data_package_state", null: false, default: "draft"
      t.string :title
      t.timestamp :sent_at
      t.timestamp :acknowledged_at
      t.timestamps
    end

    # Indexes created in transaction (no concurrently in dev)
    add_index :data_packages, :data_stream_id
    add_index :data_packages, :sender_organization_id
    add_index :data_packages, :state
    add_index :data_packages, [:data_stream_id, :state]
  end

  def down
    drop_table :data_packages
    execute "DROP TYPE IF EXISTS data_package_state;"
  end
end
