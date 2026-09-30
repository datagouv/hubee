# frozen_string_literal: true

module Portail
  module Access
    # La table de transitions du portail, reprise du portail V1, refus de proposer compris.
    # Elle fait autorité : un état qui n'y figure pas n'est ni proposé ni accepté.
    module StateTransitions
      # « Clos » s'affiche mais n'est jamais une cible : c'est l'émetteur qui ferme un dossier.
      # « Erreur d'intégration » n'y figure pas, elle est hors du périmètre servi.
      LIFECYCLE = %w[
        transmitted acknowledged in_progress awaiting_attachments refused done closed
      ].freeze

      NEVER_OFFERED = %w[closed].freeze

      # Accuser réception : atteignable depuis « Nouveau » seul, la table ne revient jamais en arrière.
      RECEIPT = "acknowledged"

      # Ce qui ne se décide pas sans avoir lu le dossier ; demander des compléments n'est pas décider.
      RETRIEVAL_REQUIRED = %w[in_progress refused done].freeze

      class << self
        # Tous les états postérieurs à l'état courant, moins ceux qu'on ne propose jamais. Un état
        # inconnu du cycle n'ouvre rien, ce qui couvre aussi les états hors périmètre.
        def allowed_from(state)
          rank = LIFECYCLE.index(state)
          return [] if rank.nil?

          LIFECYCLE[(rank + 1)..] - NEVER_OFFERED
        end

        # Une seule règle pour le menu et la cible soumise.
        def offered_from(delivery, data_stream)
          allowed_by_stream(delivery.state, data_stream)
            .difference(withheld_until_retrieved(delivery, data_stream))
        end

        # Rendus à part pour que le refus dise à l'agent pourquoi, pas qu'il a été devancé.
        def withheld_by_stream(state, data_stream)
          allowed_from(state).difference(allowed_by_stream(state, data_stream))
        end

        def withheld_until_retrieved(delivery, data_stream)
          return [] unless awaiting_retrieval?(delivery)

          allowed_by_stream(delivery.state, data_stream).intersection(RETRIEVAL_REQUIRED)
        end

        private

        # Flux illisible : on propose quand même, un refus amont explicite vaut mieux qu'une action
        # escamotée.
        def allowed_by_stream(state, data_stream)
          allowed_from(state).select { |target| data_stream.nil? || data_stream.allows?(target) }
        end

        def awaiting_retrieval?(delivery) = delivery.received_attachments.any? && !delivery.retrieved?
      end
    end
  end
end
