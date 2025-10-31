# frozen_string_literal: true

class AddUuidToSubscriptions < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    safety_assured do
      add_column :subscriptions, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    end
    add_index :subscriptions, :uuid, unique: true, algorithm: :concurrently
  end
end
