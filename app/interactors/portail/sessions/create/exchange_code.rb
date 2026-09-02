# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # Premier maillon : échange le code contre les jetons et dépose ce que ProConnect a
      # remis. Tout le reste de la chaîne juge à partir de là.
      class ExchangeCode
        include Interactor
        include SemanticLogger::Loggable

        def call
          tokens = Portail::ProConnect::Client.exchange(code: context.code)

          context.id_token = tokens.id_token
          context.info = tokens.info
          context.siret = tokens.siret
          context.idp_id = tokens.idp_id
          context.organization_label = tokens.organization_label
        rescue Portail::ProConnect::Client::Unavailable => e
          # ProConnect muet : rien n'est imputable à l'agent.
          logger.error("ProConnect indisponible", e)
          context.fail!(error: :provider_unavailable)
        end
      end
    end
  end
end
