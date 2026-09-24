# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Access::StateTransitions do
  describe ".allowed_from" do
    it "offers every later state except closed from a transmitted delivery" do
      expect(described_class.allowed_from("transmitted"))
        .to eq(%w[acknowledged in_progress awaiting_attachments refused done])
    end

    it "offers the states after acknowledged" do
      expect(described_class.allowed_from("acknowledged"))
        .to eq(%w[in_progress awaiting_attachments refused done])
    end

    it "does not offer a return to in_progress from awaiting_attachments" do
      expect(described_class.allowed_from("awaiting_attachments")).to eq(%w[refused done])
    end

    it "offers done from refused" do
      expect(described_class.allowed_from("refused")).to eq(%w[done])
    end

    it "offers nothing from done" do
      expect(described_class.allowed_from("done")).to eq([])
    end

    # Un état n'est jamais sa propre cible : réécrire l'état tenu passerait en amont sans rien
    # changer, et l'agent croirait avoir agi.
    it "never offers the current state" do
      states = Portail::Access::StatePerimeter::SERVED_STATES

      expect(states.select { |state| described_class.allowed_from(state).include?(state) }).to eq([])
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

  describe ".offered_from" do
    it "offers the table when the data stream allows awaiting attachments" do
      data_stream = build(:portail_data_stream)

      expect(described_class.offered_from("in_progress", data_stream)).to eq(%w[awaiting_attachments refused done])
    end

    it "withholds awaiting attachments when the data stream forbids it" do
      data_stream = build(:portail_data_stream, :without_awaiting_attachments)

      expect(described_class.offered_from("in_progress", data_stream)).to eq(%w[refused done])
    end

    # Une lecture en panne ne doit pas escamoter une action : l'amont tranchera.
    it "offers the table when the data stream could not be read" do
      expect(described_class.offered_from("in_progress", nil)).to eq(%w[awaiting_attachments refused done])
    end

    it "offers nothing on a terminal state whatever the data stream" do
      expect(described_class.offered_from("done", build(:portail_data_stream))).to eq([])
    end
  end

  # Ce qui permet au détail de proposer l'accusé dès que « Reçu » figure parmi les états proposés.
  describe "::RECEIPT" do
    it "is offered from transmitted only" do
      states = Portail::Access::StatePerimeter::SERVED_STATES

      expect(states.select { |state| described_class.allowed_from(state).include?(described_class::RECEIPT) })
        .to eq(%w[transmitted])
    end
  end
end
