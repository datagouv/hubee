# frozen_string_literal: true

# Resolves delivery criteria to matching subscriptions
#
# V1: Only SIRET list support
# Future V2: Add operators (_or, _and) and criteria (organization_id, subscription_id)
#
# Example V1:
#   { "siret" => ["13002526500013", "11000601200010"] }
#
# Future V2 structure:
#   {
#     "_or" => [
#       { "siret" => ["13002526500013"] },
#       { "organization_id" => ["uuid1", "uuid2"] }
#     ]
#   }
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

  # Future V2: Strategy pattern for different criteria types
  #
  # class BaseCriterion
  #   def initialize(values, data_stream)
  #     @values = Array(values)
  #     @data_stream = data_stream
  #   end
  #
  #   def resolve
  #     raise NotImplementedError
  #   end
  # end
  #
  # class SiretCriterion < BaseCriterion
  #   def resolve
  #     org_ids = Organization.where(siret: @values).pluck(:id)
  #     Set.new(base_scope.where(organization_id: org_ids).pluck(:id))
  #   end
  # end
end
