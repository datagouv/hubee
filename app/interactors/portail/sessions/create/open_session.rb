# frozen_string_literal: true

module Portail
  module Sessions
    class Create
      # L'accès est accordé : la session s'ouvre. Le contrôleur n'a plus qu'à ranger
      # l'identifiant dans le cookie — la session HTTP ne descend pas jusqu'ici.
      class OpenSession
        include Interactor

        def call
          context.provider_session = ProviderSession.create!(
            membership: context.membership,
            provider_id_token: context.id_token,
            provider_sid: context.claims[:sid],
            email: context.agent.email,
            amr: context.claims[:amr],
            acr: context.claims[:acr]
          )
          warn_without_sid
          # `update_column` et non `touch` : une connexion ne modifie pas le rattachement, son
          # `updated_at` reste celui de ses producteurs.
          context.membership.update_column(:last_signed_in_at, Time.current)

          # Émis après l'écriture, contrairement au refus : un accès n'est un fait qu'une
          # fois la session ouverte.
          Rails.event.notify(Portail::Auth::Decision.new(
            outcome: :granted,
            email: context.agent.email,
            provider_sub: context.claims[:sub],
            siret: context.siret,
            # Le libellé revendiqué par ProConnect, conservé même quand le rattachement le
            # rend redondant : il permet de constater un désaccord avec le référentiel V1.
            organization_label: context.organization_label,
            idp_id: context.idp_id,
            acr: context.claims[:acr],
            amr: context.claims[:amr],
            agent_id: context.agent.id,
            membership_id: context.membership.id,
            provider_sub_changed: context.provider_sub_changed
          ))
        end

        private

        # Le portail réclame le `sid` à chaque autorisation, mais ProConnect peut l'omettre. La connexion
        # n'en dépend pas ; la preuve d'une réauthentification, si : sur cette session, elle sera refusée
        # (CheckLoggedOut). Signalé pour qu'une omission de ProConnect se voie.
        def warn_without_sid
          return if context.claims[:sid].present?

          Rails.logger.warn("Session ProConnect sans sid : aucune réauthentification ne pourra y être prouvée",
            membership_id: context.membership.id)
        end
      end
    end
  end
end
