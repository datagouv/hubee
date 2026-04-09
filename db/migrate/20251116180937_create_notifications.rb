class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :data_package, type: :uuid, null: false,
        foreign_key: {on_delete: :cascade},
        index: false
      t.references :subscription, type: :uuid, null: false,
        foreign_key: {on_delete: :restrict},
        index: false
      t.timestamp :acknowledged_at
      t.timestamps
    end

    add_index :notifications, :data_package_id
    add_index :notifications, :subscription_id
    add_index :notifications, [:data_package_id, :subscription_id], unique: true
    add_index :notifications, :acknowledged_at
  end
end
