# frozen_string_literal: true

class DeliveryCriteriaValidator < ActiveModel::EachValidator
  class Invalid < StandardError; end

  def validate_each(record, attribute, value)
    validate_criteria!(value)
  rescue Invalid => e
    record.errors.add(attribute, e.message)
  end

  private

  def validate_criteria!(criteria)
    return if criteria.nil? || criteria.empty?

    raise Invalid, "must be a hash" unless criteria.is_a?(Hash)
    raise Invalid, "must contain only 'siret' key" unless criteria.keys == ["siret"]

    validate_siret_value!(criteria["siret"])
  end

  def validate_siret_value!(value)
    sirets = Array(value)

    raise Invalid, "siret must not be empty" if sirets.empty?

    if sirets.size > DataPackage::DELIVERY_CRITERIA_MAX_SIRETS
      raise Invalid, "siret list exceeds maximum of #{DataPackage::DELIVERY_CRITERIA_MAX_SIRETS}"
    end

    sirets.each_with_index do |siret, index|
      unless siret.is_a?(String) && siret.match?(Organization::SIRET_FORMAT)
        raise Invalid, "siret[#{index}] must be a 14-digit string"
      end
    end
  end

  # Future V2: Add support for operators (_or, _and) and additional criteria
  # (organization_id, subscription_id) with depth/count validation
end
