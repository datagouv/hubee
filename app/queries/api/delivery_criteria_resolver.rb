# frozen_string_literal: true

module API
  class DeliveryCriteriaResolver
    class << self
      def resolve(criteria, data_stream)
        sirets = Array(criteria&.dig("siret"))
        return Subscription.none if sirets.empty?

        org_ids = Organization.where(siret: sirets).pluck(:id)

        Subscription
          .where(data_stream: data_stream, organization_id: org_ids)
          .with_read_permission
      end
    end
  end
end
