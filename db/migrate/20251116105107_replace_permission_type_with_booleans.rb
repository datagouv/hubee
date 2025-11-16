# frozen_string_literal: true

class ReplacePermissionTypeWithBooleans < ActiveRecord::Migration[8.1]
  def up
    add_column :subscriptions, :can_read, :boolean, default: true, null: false
    add_column :subscriptions, :can_write, :boolean, default: false, null: false

    safety_assured do
      execute <<-SQL.squish
        UPDATE subscriptions
        SET can_read = CASE
              WHEN permission_type IN ('read', 'read_write') THEN TRUE
              ELSE FALSE
            END,
            can_write = CASE
              WHEN permission_type IN ('write', 'read_write') THEN TRUE
              ELSE FALSE
            END
      SQL

      remove_column :subscriptions, :permission_type
      execute "DROP TYPE IF EXISTS permission_type;"
    end
  end

  def down
    safety_assured do
      create_enum :permission_type, ["read", "write", "read_write"]

      add_column :subscriptions, :permission_type, :enum, enum_type: "permission_type", default: "read", null: false

      execute <<-SQL.squish
        UPDATE subscriptions
        SET permission_type = CASE
              WHEN can_read = TRUE AND can_write = TRUE THEN 'read_write'::permission_type
              WHEN can_read = TRUE AND can_write = FALSE THEN 'read'::permission_type
              WHEN can_read = FALSE AND can_write = TRUE THEN 'write'::permission_type
              ELSE 'read'::permission_type
            END
      SQL
    end

    remove_column :subscriptions, :can_read
    remove_column :subscriptions, :can_write
  end
end
