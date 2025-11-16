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

    count = {total: 0}
    validate_structure!(criteria, depth: 0, count: count)
  end

  def validate_structure!(criteria, depth:, count:)
    if depth > DataPackage::DELIVERY_CRITERIA_MAX_DEPTH
      raise Invalid, "exceeds maximum nesting depth of #{DataPackage::DELIVERY_CRITERIA_MAX_DEPTH}"
    end

    if criteria.key?("_or")
      validate_operator!("_or", criteria["_or"], depth: depth, count: count)
    elsif criteria.key?("_and")
      validate_operator!("_and", criteria["_and"], depth: depth, count: count)
    else
      validate_leaf!(criteria, count: count)
    end
  end

  def validate_operator!(operator, conditions, depth:, count:)
    raise Invalid, "#{operator} must contain an array" unless conditions.is_a?(Array)
    raise Invalid, "#{operator} must not be empty" if conditions.empty?

    conditions.each_with_index do |condition, index|
      raise Invalid, "#{operator}[#{index}] must be a hash" unless condition.is_a?(Hash)
      validate_structure!(condition, depth: depth + 1, count: count)
    end
  end

  def validate_leaf!(criteria, count:)
    count[:total] += criteria.size
    if count[:total] > DataPackage::DELIVERY_CRITERIA_MAX_COUNT
      raise Invalid, "exceeds maximum of #{DataPackage::DELIVERY_CRITERIA_MAX_COUNT} criteria"
    end

    criteria.each_key do |key|
      if key.start_with?("_")
        raise Invalid, "unknown operator: #{key}"
      elsif !DataPackage::DELIVERY_CRITERIA_SUPPORTED.include?(key)
        raise Invalid, "unsupported criterion: #{key}"
      end
    end
  end
end
