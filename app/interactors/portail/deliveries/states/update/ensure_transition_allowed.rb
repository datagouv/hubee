# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        # La cible est-elle proposée depuis l'état courant, démarche comprise ? Vérifié avant
        # d'écrire pour ne pas envoyer en amont un geste voué au refus.
        class EnsureTransitionAllowed
          include Interactor

          def call
            context.fail!(error: :invalid_request) unless transition_offered?
            context.fail!(error: :awaiting_documents_not_allowed) if awaiting_documents_withheld?
          end

          private

          def delivery = context.delivery

          def transition_offered?
            Access::StateTransitions.allows?(delivery.state, context.state)
          end

          # Même règle que le menu du détail : une seule source, la table croisée avec le profil.
          def awaiting_documents_withheld?
            return false unless context.state == "awaiting_documents"

            profile = DataStream::ProfileCache.fetch(delivery.data_stream.code)
            Access::StateTransitions.offered_from(delivery.state, profile).exclude?("awaiting_documents")
          end
        end
      end
    end
  end
end
