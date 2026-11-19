# frozen_string_literal: true

module API
  module Internal
    module V1
      # Ce qu'un client de l'API peut faire sur les rattachements d'un agent. Le sujet est le client.
      # Modifier ou retirer un rattachement est une modification de l'agent : il n'a pas de droit propre.
      class MembershipPolicy
        attr_reader :api_client

        # Le droit se juge sur le client seul : le rattachement visé n'entre pas dans la décision.
        def initialize(api_client, _membership)
          @api_client = api_client
        end

        def update? = granted?

        def destroy? = granted?

        private

        # Lu à chaque appel : un droit retiré vaut aussitôt, même pour un jeton déjà délivré.
        def granted? = OauthApplicationRight.exists?(oauth_application: api_client, right: "internal:agents:update")
      end
    end
  end
end
