# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    # Sans clé étrangère vers le sujet : la trace doit survivre à sa suppression.
    create_table :events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :eventable_type, null: false
      t.uuid :eventable_id, null: false
      t.string :event_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :events, [:eventable_type, :eventable_id]
    add_index :events, :created_at
  end
end
