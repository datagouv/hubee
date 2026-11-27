# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        module Memberships
          class Update
            include Interactor::Organizer

            # Les vérifications accumulent leurs motifs sans s'interrompre. Seule Save écrit, après la
            # vérification des codes ajoutés : la transaction ne reste jamais ouverte pendant un appel réseau.
            organize Shared::ValidatePayload, Shared::CheckDataStreams, Shared::EnsureNoRefusal, Save
          end
        end
      end
    end
  end
end
