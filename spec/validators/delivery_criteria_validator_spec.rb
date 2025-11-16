# frozen_string_literal: true

require "rails_helper"

RSpec.describe DeliveryCriteriaValidator do
  let(:model_class) do
    Class.new do
      include ActiveModel::Validations

      attr_accessor :delivery_criteria

      validates :delivery_criteria, delivery_criteria: true
    end
  end

  let(:record) { model_class.new }

  describe "basic validation" do
    it "is valid with nil criteria" do
      record.delivery_criteria = nil
      expect(record).to be_valid
    end

    it "is valid with empty hash" do
      record.delivery_criteria = {}
      expect(record).to be_valid
    end

    it "is invalid when criteria is not a hash" do
      record.delivery_criteria = "invalid"
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("must be a hash")
    end
  end

  describe "supported criteria" do
    it "is valid with siret criterion" do
      record.delivery_criteria = {"siret" => "13002526500013"}
      expect(record).to be_valid
    end

    it "is valid with organization_id criterion" do
      record.delivery_criteria = {"organization_id" => "uuid"}
      expect(record).to be_valid
    end

    it "is valid with subscription_id criterion" do
      record.delivery_criteria = {"subscription_id" => "uuid"}
      expect(record).to be_valid
    end

    it "is invalid with unsupported criterion" do
      record.delivery_criteria = {"unknown_field" => "value"}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("unsupported criterion: unknown_field")
    end
  end

  describe "operators" do
    it "is valid with _or operator" do
      record.delivery_criteria = {
        "_or" => [
          {"siret" => "13002526500013"},
          {"siret" => "11000601200010"}
        ]
      }
      expect(record).to be_valid
    end

    it "is valid with _and operator" do
      record.delivery_criteria = {
        "_and" => [
          {"siret" => "13002526500013"},
          {"organization_id" => "uuid"}
        ]
      }
      expect(record).to be_valid
    end

    it "is invalid with unknown operator" do
      record.delivery_criteria = {"_unknown" => []}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("unknown operator: _unknown")
    end

    it "is invalid when operator value is not an array" do
      record.delivery_criteria = {"_or" => "not_an_array"}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("_or must contain an array")
    end

    it "is invalid when operator array is empty" do
      record.delivery_criteria = {"_or" => []}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("_or must not be empty")
    end

    it "is invalid when operator array contains non-hash" do
      record.delivery_criteria = {"_or" => ["string"]}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("_or[0] must be a hash")
    end
  end

  describe "nesting depth limit" do
    it "is valid at maximum nesting depth (2)" do
      # depth 0: _or, depth 1: _and, depth 2: leaf
      record.delivery_criteria = {
        "_or" => [
          {
            "_and" => [
              {"siret" => "13002526500013"}
            ]
          }
        ]
      }
      expect(record).to be_valid
    end

    it "is invalid when exceeding maximum nesting depth" do
      deeply_nested = {"siret" => "13002526500013"}
      3.times { deeply_nested = {"_or" => [deeply_nested]} }

      record.delivery_criteria = deeply_nested
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("exceeds maximum nesting depth of 2")
    end
  end

  describe "criteria count limit" do
    it "is valid with maximum criteria count (20)" do
      record.delivery_criteria = {
        "_or" => [
          {"siret" => "1", "organization_id" => "2", "subscription_id" => "3"},
          {"siret" => "4", "organization_id" => "5", "subscription_id" => "6"},
          {"siret" => "7", "organization_id" => "8", "subscription_id" => "9"},
          {"siret" => "10", "organization_id" => "11", "subscription_id" => "12"},
          {"siret" => "13", "organization_id" => "14", "subscription_id" => "15"},
          {"siret" => "16", "organization_id" => "17", "subscription_id" => "18"},
          {"siret" => "19", "organization_id" => "20"}
        ]
      }
      expect(record).to be_valid
    end

    it "is invalid when exceeding maximum criteria count" do
      record.delivery_criteria = {
        "_or" => [
          {"siret" => "1", "organization_id" => "2", "subscription_id" => "3"},
          {"siret" => "4", "organization_id" => "5", "subscription_id" => "6"},
          {"siret" => "7", "organization_id" => "8", "subscription_id" => "9"},
          {"siret" => "10", "organization_id" => "11", "subscription_id" => "12"},
          {"siret" => "13", "organization_id" => "14", "subscription_id" => "15"},
          {"siret" => "16", "organization_id" => "17", "subscription_id" => "18"},
          {"siret" => "19", "organization_id" => "20", "subscription_id" => "21"}
        ]
      }
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("exceeds maximum of 20 criteria")
    end
  end

  describe "schema constants" do
    it "uses constants from DataPackage model" do
      expect(DataPackage::DELIVERY_CRITERIA_SUPPORTED).to eq(%w[siret organization_id subscription_id])
      expect(DataPackage::DELIVERY_CRITERIA_MAX_DEPTH).to eq(2)
      expect(DataPackage::DELIVERY_CRITERIA_MAX_COUNT).to eq(20)
    end
  end
end
