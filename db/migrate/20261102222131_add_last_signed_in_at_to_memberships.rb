# frozen_string_literal: true

# La dernière ouverture de session d'un agent dans cette organisation, pour que
# l'administrateur local repère les accès inutilisés. Nul : jamais connecté depuis la mise
# en place de la colonne — rien n'est reconstitué du passé.
class AddLastSignedInAtToMemberships < ActiveRecord::Migration[8.1]
  def change
    add_column :memberships, :last_signed_in_at, :datetime
  end
end
