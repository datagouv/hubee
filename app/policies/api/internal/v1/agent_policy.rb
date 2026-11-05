# frozen_string_literal: true

module API
  module Internal
    module V1
      # Ce qu'un client de l'API peut faire sur les agents. Le sujet est le client, pas un agent.
      class AgentPolicy
        attr_reader :api_client

        # L'enregistrement n'a pas d'agent à juger : seul le client compte.
        def initialize(api_client, _agent)
          @api_client = api_client
        end

        # Lu à chaque appel : un droit retiré vaut aussitôt, même pour un jeton déjà délivré.
        def create? = OauthApplicationRight.exists?(oauth_application: api_client, right: "internal:agents:create")
      end
    end
  end
end
