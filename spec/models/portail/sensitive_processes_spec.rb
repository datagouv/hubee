# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::SensitiveProcesses do
  describe ".parse" do
    it "reads a comma separated list, whatever the spacing and the case" do
      expect(described_class.parse("FLUX_RETIRE_3,dsg , Gro")).to eq(%w[FLUX_RETIRE_3 FLUX_RETIRE_1 FLUX_RETIRE_2])
    end

    # Une liste vide est un choix légitime : plus aucun processus n'est sensible.
    it "accepts an empty list" do
      expect(described_class.parse("")).to eq([])
      expect(described_class.parse(" , ")).to eq([])
    end
  end

  describe "CODES" do
    it "is frozen so no caller can widen the rule at runtime" do
      expect(described_class::CODES).to be_frozen
    end
  end
end
