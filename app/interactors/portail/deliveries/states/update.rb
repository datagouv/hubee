# frozen_string_literal: true

module Portail
  module Deliveries
    module States
      class Update
        include Interactor::Organizer

        # La cohérence d'abord : un agent dont la page a vieilli doit s'entendre dire de la
        # recharger, pas qu'une transition est impossible.
        organize Update::EnsureStateUnchanged,
          Update::EnsureTransitionAllowed,
          Update::WriteState
      end
    end
  end
end
