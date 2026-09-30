# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery do
  describe "#received_attachments" do
    it "keeps the received deposit attachments, in their order" do
      first = build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111")
      pending = build(:portail_attachment, id: "a2222222-2222-2222-2222-222222222222", state: "pending")
      last = build(:portail_attachment, id: "a3333333-3333-3333-3333-333333333333")
      delivery = build(:portail_delivery, attachments: [first, pending, last])

      expect(delivery.received_attachments).to eq([first, last])
    end

    it "is empty when no deposit attachment is received" do
      delivery = build(:portail_delivery, attachments: [build(:portail_attachment, state: "rejected")])

      expect(delivery.received_attachments).to eq([])
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
