class CreateMemberships < ActiveRecord::Migration[8.1]
  # Un rattachement n'existe que s'il a été accordé délibérément. Le portail le lit,
  # ne l'écrit jamais : sa création revient à un producteur externe.
  #
  # Table de jointure dès le premier jour, alors qu'un agent n'a aujourd'hui qu'une seule
  # organisation : c'est le multi-organisation qui coûterait cher à rattraper, pas la
  # jointure elle-même.
  def change
    create_table :memberships, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :agent, null: false, foreign_key: true, type: :uuid
      t.references :organization_link, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :memberships, [:agent_id, :organization_link_id], unique: true
  end
end
