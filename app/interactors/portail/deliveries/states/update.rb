# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        include Interactor::Organizer

        # La transition se vérifie contre l'état courant, relu au moment d'écrire : une page
        # vieillie qui soumet une cible devenue inatteignable se voit refuser par la table.
        #
        # La réponse, non rejouable, passe avant l'état : refusée, elle ne laisse pas un dossier avancé
        # sans elle. Après un échec de l'état, on relance l'état seul, jamais cet organizer.
        organize Update::EnsureTransitionAllowed,
          Update::EnsureReplyAccepted,
          Update::WriteReply,
          Update::WriteState
      end
    end
  end
end
