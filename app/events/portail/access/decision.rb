# frozen_string_literal: true

module Portail
  module Access
    # Ce que le portail a décidé en cours de session, et sur quelles bases : un refus
    # d'habilitation, ou une page servie par l'amont hors du périmètre demandé, dont
    # `dropped_ids` sont les éléments retirés. Un Data, comme Auth::Decision : jeu de clés
    # fermé, immuable d'un abonné à l'autre.
    Decision = Data.define(:outcome, :path, :agent_id, :membership_id, :dropped_ids) do
      def initialize(outcome:, path: nil, agent_id: nil, membership_id: nil, dropped_ids: nil)
        super
      end
    end
  end
end
