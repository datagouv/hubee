# frozen_string_literal: true

class AddProviderSidToProviderSessions < ActiveRecord::Migration[8.1]
  def change
    # La session ProConnect (`sid` de l'id_token) qui a ouvert ou renforcé cette session : une
    # réauthentification doit revenir d'une autre, preuve que la déconnexion a eu lieu.
    add_column :provider_sessions, :provider_sid, :string
  end
end
