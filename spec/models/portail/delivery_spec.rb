# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery do
  describe "#all_attachments" do
    it "lists the deposit pieces, then those added by the history, in its order" do
      deposited = build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111")
      first_added = build(:portail_attachment, id: "b1111111-1111-1111-1111-111111111111")
      last_added = build(:portail_attachment, id: "b2222222-2222-2222-2222-222222222222")
      delivery = build(:portail_delivery, attachments: [deposited], events: [
        build(:portail_event, attachments: [first_added]),
        build(:portail_event, attachments: []),
        build(:portail_event, attachments: [last_added])
      ])

      expect(delivery.all_attachments).to eq([deposited, first_added, last_added])
    end
  end

  describe "#received_attachments" do
    it "keeps the received deposit pieces only, in their order" do
      first = build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111")
      pending = build(:portail_attachment, id: "a2222222-2222-2222-2222-222222222222", state: "pending")
      last = build(:portail_attachment, id: "a3333333-3333-3333-3333-333333333333")
      delivery = build(:portail_delivery, attachments: [first, pending, last],
        events: [build(:portail_event, attachments: [build(:portail_attachment, id: "b1111111-1111-1111-1111-111111111111")])])

      expect(delivery.received_attachments).to eq([first, last])
    end

    it "is empty when no deposit attachment is received" do
      delivery = build(:portail_delivery, attachments: [build(:portail_attachment, state: "rejected")])

      expect(delivery.received_attachments).to eq([])
    end
  end

  describe "#all_received_attachments" do
    it "keeps the received pieces, deposited then added, in their order" do
      first = build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111")
      pending = build(:portail_attachment, id: "a2222222-2222-2222-2222-222222222222", state: "pending")
      added = build(:portail_attachment, id: "b1111111-1111-1111-1111-111111111111")
      added_pending = build(:portail_attachment, id: "b2222222-2222-2222-2222-222222222222", state: "pending")
      delivery = build(:portail_delivery, attachments: [first, pending],
        events: [build(:portail_event, attachments: [added, added_pending])])

      expect(delivery.all_received_attachments).to eq([first, added])
    end

    it "keeps the added pieces when no deposit piece is received" do
      added = build(:portail_attachment, id: "b1111111-1111-1111-1111-111111111111")
      delivery = build(:portail_delivery, attachments: [build(:portail_attachment, state: "rejected")],
        events: [build(:portail_event, attachments: [added])])

      expect(delivery.all_received_attachments).to eq([added])
    end

    it "is empty when no piece is received" do
      delivery = build(:portail_delivery, attachments: [build(:portail_attachment, state: "rejected")],
        events: [build(:portail_event, attachments: [build(:portail_attachment, state: "pending")])])

      expect(delivery.all_received_attachments).to eq([])
    end
  end

  describe "#find_attachment" do
    let(:deposited) { build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111") }
    let(:added) { build(:portail_attachment, id: "b1111111-1111-1111-1111-111111111111") }
    let(:delivery) do
      build(:portail_delivery, attachments: [deposited],
        events: [build(:portail_event, attachments: []), build(:portail_event, attachments: [added])])
    end

    it "finds a deposit piece by its identifier" do
      expect(delivery.find_attachment(deposited.id)).to eq(deposited)
    end

    it "finds a piece added by an event by its identifier" do
      expect(delivery.find_attachment(added.id)).to eq(added)
    end

    it "finds nothing for an identifier the delivery does not carry" do
      expect(delivery.find_attachment("c3333333-3333-3333-3333-333333333333")).to be_nil
    end
  end

  describe "#retrieved?" do
    histories = {
      "a single attachment download" => {event_types: %w[attachment.downloaded], retrieved: true},
      "an archive download" => {event_types: %w[attachment.all_downloaded], retrieved: true},
      "a download among other events" => {event_types: %w[delivery.state_changed attachment.downloaded message.created], retrieved: true},
      "no download at all" => {event_types: %w[delivery.state_changed message.created], retrieved: false},
      "an empty history" => {event_types: [], retrieved: false}
    }

    histories.each do |history, expectation|
      it "is #{expectation[:retrieved]} with #{history}" do
        events = expectation[:event_types].map { |event_type| build(:portail_event, event_type: event_type, metadata: {}) }

        expect(build(:portail_delivery, events: events).retrieved?).to be(expectation[:retrieved])
      end
    end

    # Une trace venue du portail V1 porte le nom d'un autre agent : elle vaut la nôtre.
    it "is true with a download by another author" do
      event = build(:portail_event, event_type: "attachment.downloaded", author: "Agent du portail V1", metadata: {})

      expect(build(:portail_delivery, events: [event]).retrieved?).to be(true)
    end
  end

  describe "#archive_filename" do
    # La convention nomme l'heure de Paris, quel que soit le fuseau de l'instant courant.
    seasons = {
      "winter time" => {now: Time.utc(2026, 1, 15, 13, 5), expected: "20260115-14.05_DGS-CERTDC-0000000000001-01.zip"},
      "summer time" => {now: Time.utc(2026, 7, 15, 22, 30), expected: "20260716-00.30_DGS-CERTDC-0000000000001-01.zip"}
    }

    seasons.each do |season, moment|
      it "names the archive after the current time in Paris in #{season}" do
        delivery = build(:portail_delivery)

        expect(travel_to(moment[:now]) { delivery.archive_filename }).to eq(moment[:expected])
      end
    end

    # Le numéro vient de l'amont et finit dans le nom d'un fichier et d'un dossier sur le disque.
    it "sanitizes the number of the delivery" do
      delivery = build(:portail_delivery, number: "../DGS\\CERTDC-42")

      expect(travel_to(Time.utc(2026, 1, 15, 13, 5)) { delivery.archive_filename }).to eq("20260115-14.05_CERTDC-42.zip")
    end
  end
end
