# frozen_string_literal: true

module Portail
  module Access
    # Les états dans lesquels le portail sert un télédossier. Le périmètre du portail, pas celui
    # d'un rattachement : hors de cette liste, ce n'est la page de personne. L'amont en sert
    # d'autres, dont l'erreur d'intégration, que HubEE, tiers de transmission, supervise lui-même.
    module StatePerimeter
      SERVED_STATES = %w[
        transmitted acknowledged in_progress awaiting_attachments done refused closed
      ].freeze

      def self.covers?(state) = SERVED_STATES.include?(state)
    end
  end
end
