class AllowNullProviderSubOnAgents < ActiveRecord::Migration[8.1]
  # Un agent est pré-créé à partir de son email administratif, avant d'avoir jamais
  # ouvert de session : son provider_sub n'est connu qu'au premier login ProConnect.
  # L'index unique reste valide — PostgreSQL autorise plusieurs NULL.
  def change
    change_column_null :agents, :provider_sub, true
  end
end
