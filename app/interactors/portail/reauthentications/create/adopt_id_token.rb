# frozen_string_literal: true

module Portail
  module Reauthentications
    class Create
      # L'ancien id_token correspond à la session ProConnect fermée au départ de la réauthentification ;
      # le `sid` suit le jeton, pour que la réauthentification suivante en exige un autre.
      # Les niveaux, eux, restent ceux de la session jusqu'à la preuve (RecordProof) : un retour sans
      # second facteur ferait sinon éjecter l'administrateur local à la requête suivante.
      class AdoptIdToken
        include Interactor

        def call
          context.provider_session.update!(provider_id_token: context.id_token, provider_sid: context.claims[:sid])
        end
      end
    end
  end
end
