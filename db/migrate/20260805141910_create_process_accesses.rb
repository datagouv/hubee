# frozen_string_literal: true

class CreateProcessAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :process_accesses, id: :uuid, default: -> { "uuidv7()" } do |t|
      # Cascade en base plutôt que `dependent:` : une habilitation ne doit pas survivre à
      # son rattachement, y compris quand la suppression ne passe pas par Rails.
      t.references :membership, type: :uuid, null: false, index: false,
        foreign_key: {on_delete: :cascade}
      t.string :process_code, null: false

      t.timestamps
    end

    # L'index commence par membership_id : il sert aussi les recherches par rattachement,
    # d'où `index: false` ci-dessus.
    add_index :process_accesses, [:membership_id, :process_code], unique: true
  end
end
