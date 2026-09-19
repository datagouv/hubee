# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Access::StateTransitions do
  describe ".allowed_from" do
    it "offers every later state except closed from a transmitted delivery" do
      expect(described_class.allowed_from("transmitted"))
        .to eq(%w[acknowledged in_progress awaiting_documents refused done])
    end

    it "offers the states after acknowledged" do
      expect(described_class.allowed_from("acknowledged"))
        .to eq(%w[in_progress awaiting_documents refused done])
    end

    it "does not offer a return to in_progress from awaiting_documents" do
      expect(described_class.allowed_from("awaiting_documents")).to eq(%w[refused done])
    end

    it "offers done from refused" do
      expect(described_class.allowed_from("refused")).to eq(%w[done])
    end

    it "offers nothing from done" do
      expect(described_class.allowed_from("done")).to eq([])
    end

    it "never offers closed" do
      states = Portail::Access::StatePerimeter::SERVED_STATES
      offered = states.flat_map { |state| described_class.allowed_from(state) }

      expect(offered).not_to include("closed")
    end

    it "offers nothing from closed" do
      expect(described_class.allowed_from("closed")).to eq([])
    end

    it "offers nothing from a state the portal does not serve" do
      expect(described_class.allowed_from("integration_error")).to eq([])
    end

    it "offers nothing from an unknown state" do
      expect(described_class.allowed_from("yolo")).to eq([])
    end

    it "only offers states the portal serves" do
      states = Portail::Access::StatePerimeter::SERVED_STATES
      offered = states.flat_map { |state| described_class.allowed_from(state) }.uniq

      expect(offered - states).to eq([])
    end
  end

  describe ".allows?" do
    it "accepts a transition the table offers" do
      expect(described_class.allows?("in_progress", "done")).to be(true)
    end

    it "refuses a transition the table does not offer" do
      expect(described_class.allows?("done", "in_progress")).to be(false)
    end

    it "refuses a move to the same state" do
      expect(described_class.allows?("in_progress", "in_progress")).to be(false)
    end

    it "refuses a move to closed" do
      expect(described_class.allows?("done", "closed")).to be(false)
    end
  end

  describe ".offered_from" do
    it "offers the table when the data stream allows awaiting documents" do
      profile = build(:portail_data_stream_profile)

      expect(described_class.offered_from("in_progress", profile)).to eq(%w[awaiting_documents refused done])
    end

    it "withholds awaiting documents when the data stream forbids it" do
      profile = build(:portail_data_stream_profile, :without_awaiting_documents)

      expect(described_class.offered_from("in_progress", profile)).to eq(%w[refused done])
    end

    it "withholds awaiting documents when the data stream was never configured for it" do
      profile = build(:portail_data_stream_profile, :unconfigured)

      expect(described_class.offered_from("in_progress", profile)).to eq(%w[refused done])
    end

    # Une lecture en panne ne doit pas escamoter une action : l'amont tranchera.
    it "offers the table when the profile could not be read" do
      expect(described_class.offered_from("in_progress", nil)).to eq(%w[awaiting_documents refused done])
    end

    it "offers nothing on a terminal state whatever the profile" do
      expect(described_class.offered_from("done", build(:portail_data_stream_profile))).to eq([])
    end
  end
end
