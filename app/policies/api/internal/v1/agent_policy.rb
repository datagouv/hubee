# frozen_string_literal: true

module API
  module Internal
    module V1
      # Ce qu'un client de l'API peut faire sur les agents. Le sujet est le client, pas un agent.
      class AgentPolicy
        attr_reader :api_client

        # Le droit se juge sur le client seul : l'agent visé n'entre pas dans la décision.
        def initialize(api_client, _agent)
          @api_client = api_client
        end

        def index? = granted?("internal:agents:read")

        def show? = granted?("internal:agents:read")

        def create? = granted?("internal:agents:create")

        def update? = granted?("internal:agents:update")

        def destroy? = granted?("internal:agents:destroy")

        private

        # Lu à chaque appel : un droit retiré vaut aussitôt, même pour un jeton déjà délivré.
        def granted?(right) = OauthApplicationRight.exists?(oauth_application: api_client, right:)
      end
    end
  end
end
