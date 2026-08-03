class CreateOrganizationLinks < ActiveRecord::Migration[8.1]
  # Pont vers le référentiel d'organisations, dont la V1 reste propriétaire pendant toute
  # la transition. On ne réplique rien : cette table ne porte qu'une référence, jamais une
  # copie du nom ni des attributs de l'organisation.
  #
  # L'index unique est notre garde-fou d'intégrité. La règle « 1 SIRET = 1 organisation »
  # est tenue par un processus côté V1, dans un référentiel hors de notre base : nous ne
  # pouvons pas l'y contraindre, seulement refuser d'enregistrer deux liens pour un SIRET.
  def change
    create_table :organization_links, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :siret, null: false
      t.timestamps
    end

    add_index :organization_links, :siret, unique: true
  end
end
