# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Index::ValidateCriteria do
  describe ".call" do
    # Le form garde ses motifs : le controller les rend tels quels.
    it "fails on invalid criteria and leaves their reasons on the form" do
      form = API::Internal::V1::AgentSearchForm.new(role: "owner", per_page: "101")

      result = described_class.call(form:)

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_criteria)
      expect(form.errors.details).to eq(
        role: [{error: :inclusion, value: "owner"}],
        per_page: [{error: :less_than_or_equal_to, value: 101, count: 100}]
      )
    end

    it "lets valid criteria through" do
      form = API::Internal::V1::AgentSearchForm.new(siret: "21750056000016", role: "member")

      expect(described_class.call(form:)).to be_success
      expect(form.errors).to be_empty
    end
  end
end
