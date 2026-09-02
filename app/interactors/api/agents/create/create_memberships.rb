# frozen_string_literal: true

module API
  module Agents
    class Create
      class CreateMemberships
        include Interactor

        def call
          index = nil
          context.memberships = payload.memberships.each_with_index.map do |membership, i|
            index = i
            create_membership(membership)
          end
        rescue ActiveRecord::RecordInvalid => e
          # Filet des règles que le payload ne duplique pas (format du téléphone, longueur du poste).
          context.fail!(error: :invalid_payload, fields: indexed_fields(e, index))
        end

        private

        def payload
          context.payload
        end

        def create_membership(membership)
          Membership.create!(
            agent: context.agent, organization_link: context.organization_links.fetch(membership.siret),
            role: membership.role, job_title: membership.job_title, phone_number: membership.phone_number
          )
        end

        def indexed_fields(error, index)
          error.record.errors.to_hash.transform_keys { |attribute| :"memberships[#{index}].#{attribute}" }
        end
      end
    end
  end
end
