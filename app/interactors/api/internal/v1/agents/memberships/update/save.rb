# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        module Memberships
          class Update
            # Une écriture sans sa trace n'a pas lieu : tout se fait dans une seule transaction.
            class Save
              include Interactor

              # Le verrou vient en premier, puis les changements se calculent : il recharge le rattachement et ses
              # habilitations, de sorte que l'avant, l'écart écrit et la trace sont ceux de l'état au moment de
              # l'écriture, non ceux lus au début de la requête. Deux modifications simultanées se suivent.
              #
              # La demande est revalidée contre cet état : « au moins un code pour un membre » et la confirmation
              # de l'accès à tous les flux portent sur le rôle et les codes actuels et résultants, et deux
              # modifications simultanées, chacune valide contre l'état lu au début, feraient sinon ensemble un
              # membre sans habilitation, ou un administrateur local ouvert à tous les flux sans confirmation.
              # Le form garde le motif de la 422.
              def call
                ActiveRecord::Base.transaction do
                  membership.lock!
                  context.fail! if form.invalid?

                  changes = form.changes
                  context.changed = changes.any?
                  next unless context.changed

                  membership.update!(changes.except(:data_stream_codes).transform_values(&:last))
                  replace_habilitations(*changes[:data_stream_codes]) if changes.key?(:data_stream_codes)
                  Event.create!(eventable: membership, event_type: "membership.updated", metadata: metadata(changes))
                end
              end

              private

              def form = context.form

              def membership = form.membership

              # Seul l'écart s'écrit : une habilitation gardée garde sa ligne.
              def replace_habilitations(before, after)
                membership.data_stream_accesses.where(data_stream_code: before - after).delete_all
                (after - before).each { membership.data_stream_accesses.create!(data_stream_code: it) }
              end

              # L'adresse de l'agent, le SIRET et le code INSEE désignent le rattachement même après sa
              # suppression. Les valeurs avant et après figurent sous `changes`, données personnelles comprises.
              def metadata(changes)
                {
                  api_client: context.api_client.name,
                  api_client_uid: context.api_client.uid,
                  request_id: context.request_id,
                  email: membership.agent.email,
                  siret: membership.organization_link.siret,
                  insee_code: membership.organization_link.insee_code,
                  changes:
                }
              end
            end
          end
        end
      end
    end
  end
end
