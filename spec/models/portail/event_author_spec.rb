# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::EventAuthor do
  describe ".for" do
    it "signs with the given name and the family name in capitals" do
      agent = build(:agent, first_name: "Camille", last_name: "Martin")

      expect(described_class.for(agent)).to eq("Camille MARTIN")
    end

    it "leaves a family name already in capitals alone" do
      agent = build(:agent, first_name: "Camille", last_name: "MARTIN")

      expect(described_class.for(agent)).to eq("Camille MARTIN")
    end

    it "keeps a compound family name whole" do
      agent = build(:agent, first_name: "Jean", last_name: "Dupont-Morel")

      expect(described_class.for(agent)).to eq("Jean DUPONT-MOREL")
    end

    # Les deux champs sont nuls tant qu'un agent n'a pas ouvert de session.
    it "signs with what it has when the given name is missing" do
      agent = build(:agent, first_name: nil, last_name: "Martin")

      expect(described_class.for(agent)).to eq("MARTIN")
    end

    it "signs with nothing when the agent has no name at all" do
      agent = build(:agent, first_name: nil, last_name: nil)

      expect(described_class.for(agent)).to eq("")
    end
  end
end
