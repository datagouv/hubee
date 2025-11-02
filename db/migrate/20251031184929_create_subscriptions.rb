# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :subscriptions, id: :uuid do |t|
      t.references :data_stream, type: :uuid, null: false,
        foreign_key: {on_delete: :cascade},
        index: false
      t.references :organization, type: :uuid, null: false,
        foreign_key: {on_delete: :cascade},
        index: false
      t.string :permission_type, null: false, default: "read"
      t.timestamps
    end

    add_index :subscriptions, :data_stream_id, algorithm: :concurrently
    add_index :subscriptions, :organization_id, algorithm: :concurrently
    add_index :subscriptions, [:data_stream_id, :organization_id], unique: true, algorithm: :concurrently, name: "index_subscriptions_on_stream_and_org"

    add_check_constraint :subscriptions,
      "permission_type IN ('read', 'write', 'read_write')",
      name: "permission_type_check"
  end
end
