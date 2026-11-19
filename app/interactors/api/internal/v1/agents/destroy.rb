# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Destroy
          include Interactor::Organizer

          # Une seule étape, sans appel réseau : la transaction porte la trace et la suppression.
          organize Remove
        end
      end
    end
  end
end
