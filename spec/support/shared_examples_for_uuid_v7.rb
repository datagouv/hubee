# frozen_string_literal: true

RSpec.shared_examples "a model with UUID v7 primary key" do
  describe "UUID v7 primary key" do
    it "uses UUID v7 format as primary key" do
      record = create(described_class.model_name.singular)
      expect(record.id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
    end

    it "generates UUIDs in chronological order" do
      first_record = create(described_class.model_name.singular)
      sleep 0.001 # ensures chronological order
      second_record = create(described_class.model_name.singular)

      expect(second_record.id).to be > first_record.id
    end
  end
end
