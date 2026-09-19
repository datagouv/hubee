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

      class << self
        # Tous les états postérieurs à l'état courant, moins ceux qu'on ne propose jamais. Un état
        # inconnu du cycle n'ouvre rien, ce qui couvre aussi les états hors périmètre.
        def allowed_from(state)
          rank = LIFECYCLE.index(state)
          return [] if rank.nil?

          LIFECYCLE[(rank + 1)..] - NEVER_OFFERED
        end

        # La table, moins ce que le flux refuse : ce que le menu propose et ce qu'une cible soumise
        # doit vérifier, une seule règle pour les deux. Flux illisible : on propose quand même, un
        # refus amont explicite vaut mieux qu'une action escamotée par une lecture en panne.
        def offered_from(state, data_stream)
          states = allowed_from(state)
          return states if data_stream.nil?

          states.select { |candidate| data_stream.allows?(candidate) }
        end
      end
    end
  end
end
