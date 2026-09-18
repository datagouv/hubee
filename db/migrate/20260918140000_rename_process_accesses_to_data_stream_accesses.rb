# frozen_string_literal: true

# Les habilitations désignent des flux, comme le reste du portail : le vocabulaire
# « processus » était celui de la V1.
class RenameProcessAccessesToDataStreamAccesses < ActiveRecord::Migration[8.1]
  # Un renommage n'est pas sûr sous trafic : l'ancien code lit encore l'ancienne table le
  # temps du déploiement. Assumé ici — la table est minuscule et le portail redémarre à
  # chaque déploiement.
  def change
    safety_assured do
      # L'index d'abord, sous un nom explicite : celui que Rails dériverait des nouveaux noms
      # dépasserait les 63 caractères de Postgres et serait haché.
      rename_index :process_accesses, "index_process_accesses_on_membership_id_and_process_code",
        "index_data_stream_accesses_on_membership_and_code"
      rename_table :process_accesses, :data_stream_accesses
      rename_column :data_stream_accesses, :process_code, :data_stream_code
    end
  end
end
