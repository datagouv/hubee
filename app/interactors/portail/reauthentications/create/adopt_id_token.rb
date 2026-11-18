# frozen_string_literal: true

module Portail
  module Reauthentications
    class Create
      # L'ancien id_token correspond à la session ProConnect fermée au départ de la réauthentification.
      # Les niveaux, eux, restent ceux de la session jusqu'à la preuve (RecordProof) : un retour sans
      # second facteur ferait sinon éjecter l'administrateur local à la requête suivante.
      class AdoptIdToken
        include Interactor

        def call
          context.provider_session.update!(provider_id_token: context.id_token)
        end
      end
    end
  end
end
