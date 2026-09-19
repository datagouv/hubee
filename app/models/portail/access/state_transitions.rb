# frozen_string_literal: true

module Portail
  module Access
    # La table de transitions du portail, reprise du portail V1, refus de proposer compris.
    # Elle fait autorité : un état qui n'y figure pas n'est ni proposé ni accepté.
    module StateTransitions
      # « Clos » s'affiche mais n'est jamais une cible : c'est l'émetteur qui ferme un dossier.
      # « Erreur d'intégration » n'y figure pas, elle est hors du périmètre servi.
      LIFECYCLE = %w[
        transmitted acknowledged in_progress awaiting_documents refused done closed
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

        def allows?(from_state, to_state) = allowed_from(from_state).include?(to_state)

        # La table, moins ce que la démarche refuse. Profil inconnu : on propose quand même, un
        # refus amont explicite vaut mieux qu'une action escamotée par une lecture en panne.
        def offered_from(state, profile)
          states = allowed_from(state)
          return states if profile.nil? || profile.awaiting_documents_allowed?

          states - ["awaiting_documents"]
        end
      end
    end
  end
end
