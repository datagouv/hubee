# frozen_string_literal: true

module API
  module Internal
    module Agents
      class Create
        include Interactor::Organizer

        # Les vérifications accumulent leurs motifs sans s'interrompre. Seule la dernière étape
        # écrit, après les appels réseau : la transaction ne reste jamais ouverte pendant l'un d'eux.
        organize ValidatePayload, CheckMemberships, CheckOrganization, CheckDataStreams, EnsureNoRefusal, Register
      end
    end
  end
end
