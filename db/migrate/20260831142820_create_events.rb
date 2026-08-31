class CreateEvents < ActiveRecord::Migration[8.1]
  # Deux absences, seules choses qu'on ne peut pas lire dans le code : pas d'`updated_at`, une
  # trace ne se réécrit pas ; pas de clé étrangère, elle doit survivre à ce qu'elle décrit.
  def change
    create_table :events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.datetime :created_at, null: false
      t.uuid :eventable_id, null: false
      t.string :eventable_type, null: false
      t.string :event_type, null: false
      t.jsonb :metadata, null: false, default: {}

      t.index [:eventable_type, :eventable_id]
      t.index :created_at
      t.index :event_type
    end
  end
end
