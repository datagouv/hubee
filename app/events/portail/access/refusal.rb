# frozen_string_literal: true

module Portail
  module Access
    # Ce que le portail a refusé en cours de session, et sur quelles bases : une démarche hors
    # du périmètre de lecture, ou une page servie par l'amont hors du périmètre demandé, dont
    # `dropped_ids` sont les éléments retirés. Un Data, comme Auth::Decision : jeu de clés
    # fermé, immuable d'un abonné à l'autre.
    Refusal = Data.define(:reason, :path, :agent_id, :membership_id, :dropped_ids) do
      def initialize(reason:, path: nil, agent_id: nil, membership_id: nil, dropped_ids: nil)
        super
      end
    end
  end
end
