# frozen_string_literal: true

module API
  module Internal
    module V1
      module Agents
        class Update
          # Une écriture sans sa trace n'a pas lieu : tout se fait dans une seule transaction.
          class Save
            include Interactor
            include TraceMetadata

            # Le verrou vient en premier, puis les changements se calculent : il recharge l'agent, de sorte que
            # l'avant et la trace sont ceux de l'état au moment de l'écriture, non ceux lus au début de la
            # requête. Il fait aussi attendre un enregistrement ou une suppression simultanés du même agent.
            def call
              ActiveRecord::Base.transaction do
                agent.lock!
                changes = form.changes
                context.changed = changes.any?
                next unless context.changed

                agent.update!(changes.transform_values(&:last))
                Event.create!(eventable: agent, event_type: "agent.updated", metadata: metadata(changes))
              end
            rescue ActiveRecord::RecordNotUnique
              # Un appel simultané a pris l'adresse entre CheckEmailAvailability et l'écriture : l'index
              # unique la refuse.
              context.fail!(refusals: [:email_taken])
            rescue ActiveRecord::RecordInvalid => e
              # Le plus souvent, la validation d'unicité d'Agent voit cette adresse avant l'index.
              raise unless e.record.errors.of_kind?(:email, :taken)

              context.fail!(refusals: [:email_taken])
            end

            private

            def form = context.form

            def agent = form.agent

            # L'adresse est la nouvelle après un changement : elle désigne l'agent même après sa suppression.
            # Les valeurs avant et après figurent sous `changes`, données personnelles comprises.
            def metadata(changes)
              {
                **actor_metadata,
                email: agent.email,
                changes:
              }
            end
          end
        end
      end
    end
  end
end
