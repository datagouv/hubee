# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # Dernière étape, une fois l'accès accordé : la fiche est alignée sur l'identité
      # attestée par ProConnect, qui fait foi. Écrire plus tôt graverait une décision non
      # rendue — une tentative refusée laisserait sa trace.
      #
      # Pas d'adresse ici : FindAgent n'admet un agent que si la sienne est déjà celle du
      # jeton, à la normalisation près. La réécrire ne changerait rien.
      class SyncAgentIdentity
        include Interactor

        def call
          context.agent.update!(
            provider_sub: context.claims[:sub],
            first_name: context.info[:first_name],
            last_name: context.info[:last_name]
          )
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
          # Deux connexions simultanées d'un agent jamais rattaché : la seconde bute sur
          # l'index unique. L'agent est légitime et réessayer aboutira, l'autre requête
          # ayant déjà posé le `sub` — d'où la page d'échec, qui invite à recommencer.
          context.fail!(error: :sign_in_conflict)
        end
      end
    end
  end
end
