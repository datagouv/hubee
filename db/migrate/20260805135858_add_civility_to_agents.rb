# frozen_string_literal: true

# Chaîne et non type PostgreSQL, contrairement au rôle du rattachement : une civilité fausse
# est un défaut d'affichage, pas un privilège usurpé.
class AddCivilityToAgents < ActiveRecord::Migration[8.1]
  def change
    add_column :agents, :civility, :string
  end
end
