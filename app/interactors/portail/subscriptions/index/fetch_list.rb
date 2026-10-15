# frozen_string_literal: true

module Portail
  module Subscriptions
    class Index
      class FetchList
        include Interactor

        # Sans le cache du filtre des télédossiers : un abonnement qu'on vient de faire ajouter
        # doit se voir ici tout de suite.
        def call
          link = context.membership.organization_link
          context.subscriptions = HubAPI::Subscriptions.list(siret: link.siret, insee_code: link.insee_code)
        rescue HubAPI::Error => e
          # L'incident est déjà signalé par Portail::HubAPI : il ne reste qu'à journaliser et à échouer.
          # Au-delà de 100 abonnements, la gem refuse aussi par cette voie, alerté comme une panne : avec
          # 51 flux en production en septembre 2026, ce serait un référentiel cassé. À revoir si le
          # catalogue approche ce plafond.
          Rails.logger.error("Abonnements indisponibles — #{e.class} : #{e.message}")
          context.fail!(error: :unavailable)
        end
      end
    end
  end
end
