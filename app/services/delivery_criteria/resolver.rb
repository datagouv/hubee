# frozen_string_literal: true

module DeliveryCriteria
  class Resolver
    class << self
      def resolve(criteria, data_stream)
        return Subscription.none if criteria.blank?

        subscription_ids = parse_criteria(criteria, data_stream, depth: 0)
        Subscription.where(id: subscription_ids.to_a)
      end

      private

      def parse_criteria(criteria, data_stream, depth:)
        if depth > DataPackage::DELIVERY_CRITERIA_MAX_DEPTH
          raise DeliveryCriteriaValidator::Invalid,
            "exceeds maximum nesting depth of #{DataPackage::DELIVERY_CRITERIA_MAX_DEPTH}"
        end

        if criteria.key?("_or")
          parse_or(criteria["_or"], data_stream, depth: depth + 1)
        elsif criteria.key?("_and")
          parse_and(criteria["_and"], data_stream, depth: depth + 1)
        else
          parse_implicit_and(criteria, data_stream)
        end
      end

      def parse_or(conditions, data_stream, depth:)
        conditions.reduce(Set.new) do |result, condition|
          result | parse_criteria(condition, data_stream, depth: depth)
        end
      end

      def parse_and(conditions, data_stream, depth:)
        conditions.map { |condition| parse_criteria(condition, data_stream, depth: depth) }.reduce(:&) || Set.new
      end

      def parse_implicit_and(criteria, data_stream)
        validate_criteria_keys!(criteria)

        results = criteria.map do |key, value|
          resolve_criterion(key, value, data_stream)
        end

        results.reduce(:&) || Set.new
      end

      def validate_criteria_keys!(criteria)
        criteria.each_key do |key|
          if key.start_with?("_")
            raise DeliveryCriteriaValidator::Invalid, "unknown operator: #{key}"
          elsif !DataPackage::DELIVERY_CRITERIA_SUPPORTED.include?(key)
            raise DeliveryCriteriaValidator::Invalid, "unsupported criterion: #{key}"
          end
        end
      end

      def resolve_criterion(key, value, data_stream)
        criterion_class_for(key).new(value, data_stream).resolve
      end

      def criterion_class_for(key)
        class_name = "#{key.camelize}Criterion"
        const_get(class_name)
      end
    end

    class BaseCriterion
      attr_reader :values, :data_stream

      def initialize(values, data_stream)
        @values = Array(values)
        @data_stream = data_stream
      end

      def resolve
        raise NotImplementedError, "#{self.class} must implement #resolve"
      end

      private

      def base_scope
        Subscription.where(data_stream: data_stream).with_read_permission
      end
    end

    class SiretCriterion < BaseCriterion
      def resolve
        org_ids = Organization.where(siret: values).pluck(:id)
        Set.new(base_scope.where(organization_id: org_ids).pluck(:id))
      end
    end

    class OrganizationIdCriterion < BaseCriterion
      def resolve
        Set.new(base_scope.where(organization_id: values).pluck(:id))
      end
    end

    class SubscriptionIdCriterion < BaseCriterion
      def resolve
        Set.new(base_scope.where(id: values).pluck(:id))
      end
    end

    private_constant :BaseCriterion, :SiretCriterion, :OrganizationIdCriterion, :SubscriptionIdCriterion
  end
end
