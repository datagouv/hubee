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
      delivery = build(:portail_delivery, :retrieved, state: "in_progress")

      expect(described_class.offered_from(delivery, build(:portail_data_stream))).to eq(%w[awaiting_attachments refused done])
    end

    it "withholds awaiting attachments when the data stream forbids it" do
      delivery = build(:portail_delivery, :retrieved, state: "in_progress")
      data_stream = build(:portail_data_stream, :without_awaiting_attachments)

      expect(described_class.offered_from(delivery, data_stream)).to eq(%w[refused done])
    end

    # Une lecture en panne ne doit pas escamoter une action : l'amont tranchera.
    it "offers the table when the data stream could not be read" do
      delivery = build(:portail_delivery, :retrieved, state: "in_progress")

      expect(described_class.offered_from(delivery, nil)).to eq(%w[awaiting_attachments refused done])
    end

    it "offers nothing on a terminal state whatever the data stream" do
      delivery = build(:portail_delivery, :retrieved, state: "done")

      expect(described_class.offered_from(delivery, build(:portail_data_stream))).to eq([])
    end

    context "when the delivery has to be retrieved first" do
      downloaded = {event_type: "attachment.downloaded", content: "certificat.pdf", metadata: {}}
      deliveries = {
        "a received attachment never retrieved" => {
          attachments: [{state: "received"}], events: [], offered: %w[acknowledged awaiting_attachments]
        },
        "a received attachment retrieved alone" => {
          attachments: [{state: "received"}], events: [downloaded], offered: %w[acknowledged in_progress awaiting_attachments refused done]
        },
        "one retrieval for two received attachments" => {
          attachments: [{state: "received"}, {id: "a2222222-2222-2222-2222-222222222222", filename: "certificat.xml", state: "received"}], events: [downloaded],
          offered: %w[acknowledged in_progress awaiting_attachments refused done]
        },
        "no received attachment" => {
          attachments: [{state: "pending"}, {id: "a2222222-2222-2222-2222-222222222222", state: "rejected"}], events: [],
          offered: %w[acknowledged in_progress awaiting_attachments refused done]
        },
        "no attachment at all" => {
          attachments: [], events: [], offered: %w[acknowledged in_progress awaiting_attachments refused done]
        },
        # Une pièce ajoutée peut être la réponse de l'agent : elle ne retient aucune décision.
        "a received attachment in a complement only" => {
          attachments: [{state: "pending"}],
          events: [{event_type: "attachment.created", content: "complement.pdf", metadata: {},
                    attachments: [{id: "a3333333-3333-3333-3333-333333333333", filename: "complement.pdf", state: "received"}]}],
          offered: %w[acknowledged in_progress awaiting_attachments refused done]
        }
      }

      def build_event(attachments: [], **attributes)
        build(:portail_event, **attributes, attachments: attachments.map { |attachment| build(:portail_attachment, **attachment) })
      end

      deliveries.each do |description, row|
        it "offers #{row[:offered].join(", ")} on a new delivery with #{description}" do
          delivery = build(:portail_delivery, state: "transmitted",
            attachments: row[:attachments].map { |attributes| build(:portail_attachment, **attributes) },
            events: row[:events].map { |attributes| build_event(**attributes) })

          expect(described_class.offered_from(delivery, build(:portail_data_stream))).to eq(row[:offered])
        end
      end

      it "offers no decision from awaiting attachments until retrieved" do
        delivery = build(:portail_delivery, state: "awaiting_attachments", events: [])

        expect(described_class.offered_from(delivery, build(:portail_data_stream))).to eq([])
      end

      it "offers no move from refused to done until retrieved" do
        delivery = build(:portail_delivery, state: "refused", events: [])

        expect(described_class.offered_from(delivery, build(:portail_data_stream))).to eq([])
      end

      it "withholds the decisions even when the data stream could not be read" do
        delivery = build(:portail_delivery, state: "transmitted", events: [])

        expect(described_class.offered_from(delivery, nil)).to eq(%w[acknowledged awaiting_attachments])
      end

      it "adds the data stream refusal to its own" do
        delivery = build(:portail_delivery, state: "transmitted", events: [])
        data_stream = build(:portail_data_stream, :without_awaiting_attachments)

        expect(described_class.offered_from(delivery, data_stream)).to eq(%w[acknowledged])
      end
    end
  end

  describe ".withheld_by_stream" do
    it "withholds what the data stream forbids among what the table offers" do
      data_stream = build(:portail_data_stream, :without_awaiting_attachments)

      expect(described_class.withheld_by_stream("in_progress", data_stream)).to eq(%w[awaiting_attachments])
    end

    it "withholds nothing the table does not offer" do
      data_stream = build(:portail_data_stream, :without_awaiting_attachments)

      expect(described_class.withheld_by_stream("done", data_stream)).to eq([])
    end

    it "withholds nothing when the data stream could not be read" do
      expect(described_class.withheld_by_stream("in_progress", nil)).to eq([])
    end
  end

  describe ".withheld_until_retrieved" do
    it "withholds the decisions on a new delivery never retrieved" do
      delivery = build(:portail_delivery, state: "transmitted", events: [])

      expect(described_class.withheld_until_retrieved(delivery, build(:portail_data_stream))).to eq(%w[in_progress refused done])
    end

    it "only withholds what the table offers" do
      delivery = build(:portail_delivery, state: "awaiting_attachments", events: [])

      expect(described_class.withheld_until_retrieved(delivery, build(:portail_data_stream))).to eq(%w[refused done])
    end

    # Récupérer ne lèverait pas le refus du flux.
    it "only withholds what the data stream allows" do
      delivery = build(:portail_delivery, state: "transmitted", events: [])
      data_stream = build(:portail_data_stream, allowed_states: %w[transmitted acknowledged in_progress refused closed])

      expect(described_class.withheld_until_retrieved(delivery, data_stream)).to eq(%w[in_progress refused])
    end

    it "withholds the decisions when the data stream could not be read" do
      delivery = build(:portail_delivery, state: "transmitted", events: [])

      expect(described_class.withheld_until_retrieved(delivery, nil)).to eq(%w[in_progress refused done])
    end

    it "withholds nothing once retrieved" do
      delivery = build(:portail_delivery, :retrieved, state: "transmitted")

      expect(described_class.withheld_until_retrieved(delivery, build(:portail_data_stream))).to eq([])
    end

    it "withholds nothing without a received attachment" do
      delivery = build(:portail_delivery, state: "transmitted", events: [],
        attachments: [build(:portail_attachment, state: "pending")])

      expect(described_class.withheld_until_retrieved(delivery, build(:portail_data_stream))).to eq([])
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

  # Ce qui borne la proposition de commencer l'instruction aux deux états d'avant la lecture.
  describe "::INSTRUCTION" do
    it "is offered from transmitted and acknowledged only" do
      states = Portail::Access::StatePerimeter::SERVED_STATES

      expect(states.select { |state| described_class.allowed_from(state).include?(described_class::INSTRUCTION) })
        .to eq(%w[transmitted acknowledged])
    end
  end
end
