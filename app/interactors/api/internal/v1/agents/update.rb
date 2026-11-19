# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Update
          include Interactor::Organizer

          # Seule Save écrit, après les vérifications qui accumulent leurs motifs sans s'interrompre.
          organize Shared::ValidatePayload, CheckEmailAvailability, Shared::EnsureNoRefusal, Save
        end
      end
    end
  end
end
