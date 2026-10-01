# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      # Le changement d'état accompagné d'une réponse (la pièce de l'agent), avec ou sans message.
      class UpdateWithReply
        include Interactor::Organizer

        # La réponse, non rejouable, passe avant l'état : refusée, elle ne laisse pas un dossier avancé
        # sans elle. Après un échec de l'état, on relance l'état seul, jamais cet organizer.
        organize Shared::EnsureTransitionAllowed,
          Shared::EnsureMessageAccepted,
          UpdateWithReply::EnsureReplyAccepted,
          UpdateWithReply::WriteReply,
          Shared::WriteState
      end
    end
  end
end
