# frozen_string_literal: true

module API
  module Internal
    module Agents
      class Create
        # Une écriture sans sa trace n'a pas lieu : tout se fait dans une seule transaction.
        class Register
          include Interactor

          def call
            ActiveRecord::Base.transaction do
              agent, created = find_or_create_agent
              membership = create_membership(agent)
              Event.create!(eventable: agent, event_type: "agent.created", metadata:) if created
              Event.create!(eventable: membership, event_type: "membership.created", metadata:)
              context.membership = membership
            end
          end

          private

          def form = context.form

          # Une seule requête, sans erreur si l'adresse existe : find_or_create_by! cherche puis insère, et
          # un appel simultané qui crée le même agent entre les deux le ferait échouer. L'identité d'un agent
          # connu n'est jamais modifiée.
          # Le verrou fait attendre un autre enregistrement du même agent jusqu'à la fin de cette transaction :
          # sa règle « un rattachement par SIRET », qu'aucun index ne peut tenir, voit alors celui créé ici.
          # `insert` ne passe pas par les validations d'Agent : c'est AgentForm qui les porte.
          def find_or_create_agent
            inserted = Agent.insert(
              {email: form.email, first_name: form.first_name, last_name: form.last_name, civility: form.civility},
              unique_by: :email
            )
            [Agent.lock.find_by!(email: form.email), inserted.any?]
          end

          def create_membership(agent)
            membership = attach(agent, find_or_create_organization_link)
            form.data_stream_codes.each { membership.data_stream_accesses.create!(data_stream_code: it) }
            membership
          end

          # Un appel simultané a pu rattacher l'agent depuis CheckMemberships : c'est un rejeu. Le verrou
          # le fait attendre, puis la validation d'unicité le voit. Le rescue de l'index est un filet si le
          # verrou disparaît un jour.
          def attach(agent, organization_link)
            Membership.create!(
              agent:, organization_link:, role: form.role,
              job_title: form.job_title, phone_number: form.phone_number, mobile_phone_number: form.mobile_phone_number
            )
          rescue ActiveRecord::RecordInvalid => e
            if e.record.errors.of_kind?(:agent_id, :taken)
              context.fail!(refusals: [:already_attached])
            elsif e.record.errors.of_kind?(:organization_link, :siret_already_attached)
              context.fail!(refusals: [:siret_already_attached])
            else
              raise
            end
          rescue ActiveRecord::RecordNotUnique
            context.fail!(refusals: [:already_attached])
          end

          # Deux premiers agents d'une organisation enregistrés en parallèle créent le même lien.
          def find_or_create_organization_link
            OrganizationLink.insert({siret: form.siret, insee_code: form.insee_code}, unique_by: %i[siret insee_code])
            OrganizationLink.find_by!(siret: form.siret, insee_code: form.insee_code)
          end

          # Ni nom ni téléphone : l'adresse suffit à désigner l'agent, même après sa suppression.
          def metadata
            {
              api_client: context.api_client.name,
              api_client_uid: context.api_client.uid,
              request_id: context.request_id,
              email: form.email,
              siret: form.siret,
              insee_code: form.insee_code,
              role: form.role,
              data_stream_codes: form.data_stream_codes
            }
          end
        end
      end
    end
  end
end
