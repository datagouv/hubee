# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        include Interactor::Organizer

        # La transition se vérifie contre l'état courant, relu au moment d'écrire : une page
        # vieillie qui soumet une cible devenue inatteignable se voit refuser par la table.
        organize Update::EnsureTransitionAllowed,
          Update::WriteState
      end
    end
  end
end
