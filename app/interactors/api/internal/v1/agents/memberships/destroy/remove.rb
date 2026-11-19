# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        module Memberships
          class Destroy
            # Un retrait sans sa trace n'a pas lieu : tout se fait dans une seule transaction.
            class Remove
              include Interactor

              # Les habilitations et les sessions du rattachement partent par la cascade en base.
              #
              # Le verrou vient en premier : il fait attendre une modification simultanée du rattachement, et le
              # recharge pour que la trace décrive l'état supprimé, non celui lu au début de la requête.
              def call
                ActiveRecord::Base.transaction do
                  membership.lock!
                  Event.create!(eventable: membership, event_type: "membership.deleted", metadata:)
                  membership.destroy!
                end
              end

              private

              def membership = context.membership

              # Écrites avant la suppression : après elle, le rattachement n'est plus lisible. L'adresse de
              # l'agent, le SIRET et le code INSEE le désignent encore une fois la ligne disparue.
              def metadata
                {
                  api_client: context.api_client.name,
                  api_client_uid: context.api_client.uid,
                  request_id: context.request_id,
                  email: membership.agent.email,
                  siret: membership.organization_link.siret,
                  insee_code: membership.organization_link.insee_code,
                  role: membership.role,
                  data_stream_codes: membership.data_stream_codes.sort
                }
              end
            end
          end
        end
      end
    end
  end
end
