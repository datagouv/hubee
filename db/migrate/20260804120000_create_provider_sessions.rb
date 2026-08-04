# frozen_string_literal: true

class CreateProviderSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :provider_sessions, id: :uuid, default: -> { "uuidv7()" } do |t|
      # Nul quand l'accès a été refusé : l'authentification ProConnect a bien eu lieu,
      # HubEE n'a simplement pas ouvert de session.
      t.uuid :membership_id
      t.text :provider_id_token, null: false
      # L'adresse présentée à cette authentification, et non celle de l'agent aujourd'hui :
      # un fait daté, que la correction ultérieure d'une fiche ne doit pas réécrire. C'est
      # aussi la seule trace disponible quand le refus est « compte inconnu ».
      t.string :email, null: false
      t.string :denial_reason
      t.string :amr, array: true, null: false, default: []
      t.string :organization_label
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    # Cascade en base plutôt que `dependent:` au niveau modèle : elle ne se contourne ni
    # par `delete_all`, ni par du SQL direct. Retirer un rattachement met fin aux sessions
    # ouvertes à ce titre — sans lui, elles n'ont plus d'objet.
    add_foreign_key :provider_sessions, :memberships, on_delete: :cascade
    add_index :provider_sessions, :membership_id
    # La purge balaie sur ces deux colonnes.
    add_index :provider_sessions, :created_at
    add_index :provider_sessions, :updated_at
  end
end
