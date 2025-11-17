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

  describe "siret validation" do
    it "is valid with single siret string" do
      record.delivery_criteria = {"siret" => "13002526500013"}
      expect(record).to be_valid
    end

    it "is valid with siret array" do
      record.delivery_criteria = {"siret" => ["13002526500013", "11000601200010"]}
      expect(record).to be_valid
    end

    it "is invalid with non-siret key" do
      record.delivery_criteria = {"organization_id" => "uuid"}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("must contain only 'siret' key")
    end

    it "is invalid with multiple keys" do
      record.delivery_criteria = {"siret" => "13002526500013", "other" => "value"}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("must contain only 'siret' key")
    end

    it "is invalid with empty siret array" do
      record.delivery_criteria = {"siret" => []}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("siret must not be empty")
    end

    it "is invalid with invalid siret format (not 14 digits)" do
      record.delivery_criteria = {"siret" => "123"}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("siret[0] must be a 14-digit string")
    end

    it "is invalid with non-numeric siret" do
      record.delivery_criteria = {"siret" => "1300252650001X"}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("siret[0] must be a 14-digit string")
    end

    it "is invalid with non-string siret" do
      record.delivery_criteria = {"siret" => 13002526500013}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("siret[0] must be a 14-digit string")
    end

    it "is invalid when siret array has invalid element" do
      record.delivery_criteria = {"siret" => ["13002526500013", "invalid"]}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("siret[1] must be a 14-digit string")
    end
  end

  describe "siret count limit" do
    it "is valid with maximum sirets (100)" do
      sirets = (1..100).map { |i| format("%014d", i) }
      record.delivery_criteria = {"siret" => sirets}
      expect(record).to be_valid
    end

    it "is invalid when exceeding maximum sirets" do
      sirets = (1..101).map { |i| format("%014d", i) }
      record.delivery_criteria = {"siret" => sirets}
      expect(record).not_to be_valid
      expect(record.errors[:delivery_criteria]).to include("siret list exceeds maximum of 100")
    end
  end

  describe "schema constants" do
    it "uses constants from DataPackage model" do
      expect(DataPackage::DELIVERY_CRITERIA_SUPPORTED).to eq(%w[siret])
      expect(DataPackage::DELIVERY_CRITERIA_MAX_SIRETS).to eq(100)
    end
  end
end
