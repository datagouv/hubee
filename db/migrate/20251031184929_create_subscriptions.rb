# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def up
    # Create PostgreSQL ENUM type for permission_type (requires DDL transaction)
    create_enum "permission_type", ["read", "write", "read_write"]

    create_table :subscriptions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :data_stream, type: :uuid, null: false,
        foreign_key: {on_delete: :cascade},
        index: false
      t.references :organization, type: :uuid, null: false,
        foreign_key: {on_delete: :cascade},
        index: false
      t.enum :permission_type, enum_type: "permission_type", null: false, default: "read"
      t.timestamps
    end

    # Indexes created in transaction (no concurrently in dev)
    add_index :subscriptions, :data_stream_id
    add_index :subscriptions, :organization_id
    add_index :subscriptions, [:data_stream_id, :organization_id], unique: true, name: "index_subscriptions_on_stream_and_org"
  end

  def down
    drop_table :subscriptions
    execute "DROP TYPE IF EXISTS permission_type;"
  end
end
