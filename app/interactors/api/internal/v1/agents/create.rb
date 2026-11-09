# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Create
          include Interactor::Organizer

          # Les vérifications accumulent leurs motifs sans s'interrompre. Seule Register
          # écrit, après les appels réseau : la transaction ne reste jamais ouverte pendant l'un d'eux.
          organize ValidatePayload, CheckMemberships, CheckOrganization, CheckDataStreams, EnsureNoRefusal, Register,
            EnqueueInvitation
        end
      end
    end
  end
end
