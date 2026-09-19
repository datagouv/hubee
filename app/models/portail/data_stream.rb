# frozen_string_literal: true

module Portail
  # Un flux tel que le référentiel le sert : ce que le portail en sait. ⚠️ Lire ce qu'il autorise
  # ne suffit pas, c'est au portail de le faire respecter.
  #
  # Homonyme de ::DataStream, le modèle ActiveRecord : dans `module Portail`, un `DataStream` nu
  # résout vers cette constante-ci.
  DataStream = Data.define(:code, :name, :allowed_states) do
    # La liste arrive déjà résolue de l'amont : un flux jamais paramétré n'y autorise pas
    # l'attente de compléments.
    def allows?(state) = allowed_states.include?(state)
  end
end
