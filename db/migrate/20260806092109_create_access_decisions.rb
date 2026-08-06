# frozen_string_literal: true

class CreateAccessDecisions < ActiveRecord::Migration[8.1]
  def change
    create_enum "access_outcome", ["granted", "denied"]

    create_table :access_decisions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.enum :outcome, enum_type: "access_outcome", null: false
      t.string :reason

      # Ce que ProConnect a présenté — revendiqué, pas vérifié.
      t.string :email
      t.string :provider_sub
      t.string :siret
      t.string :organization_label
      t.string :idp_id
      t.string :acr
      t.string :amr, array: true, default: [], null: false

      # Ce que le portail a résolu. Sans clé étrangère : une piste d'audit doit survivre à
      # la suppression de son sujet, une cascade effacerait l'histoire.
      t.uuid :agent_id
      t.uuid :membership_id
      t.boolean :provider_sub_changed, null: false, default: false

      # Contexte de la requête.
      t.string :ip_address
      t.text :user_agent
      t.string :request_id

      t.timestamps
    end

    add_index :access_decisions, :created_at   # purge et questions temporelles
    add_index :access_decisions, :email        # le support cherche par adresse
    add_index :access_decisions, :siret        # le pilotage agrège par organisation
    add_index :access_decisions, :reason
  end
end
