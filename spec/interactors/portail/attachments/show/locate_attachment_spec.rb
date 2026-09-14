# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show::LocateAttachment do
  it "finds the piece among the ones that came with the deposit" do
    attachment = build(:portail_attachment, id: "b2222222-2222-2222-2222-222222222222")
    delivery = build(:portail_delivery, attachments: [build(:portail_attachment), attachment])

    result = described_class.call(delivery: delivery, id: "b2222222-2222-2222-2222-222222222222")

    expect(result).to be_success
    expect(result.attachment).to eq(attachment)
  end

  # Aucun appel amont n'a lieu ici : ce qui n'est pas livrable se voit dans l'inventaire.
  # L'identifiant en champ, et `reason` sépare la pièce inconnue de l'état qui l'empêche.
  it "fails as not found, logged, for a piece the delivery does not carry" do
    delivery = build(:portail_delivery)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(delivery: delivery, id: "c3333333-3333-3333-3333-333333333333")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Pièce non livrable",
      payload_includes: {delivery_id: delivery.id, id: "c3333333-3333-3333-3333-333333333333", reason: :unknown}
    ))
  end

  # Une pièce ajoutée ensuite vit sur son événement, hors du périmètre de cette adresse.
  it "fails as not found for a piece carried by an event only" do
    attachment = build(:portail_attachment, id: "e2222222-2222-2222-2222-222222222222")
    delivery = build(:portail_delivery, events: [build(:portail_event, attachments: [attachment])])

    result = described_class.call(delivery: delivery, id: "e2222222-2222-2222-2222-222222222222")

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
  end

  # Seule une pièce effectivement reçue est livrable. Les autres états existent et restent
  # consultables à l'inventaire, mais ne se récupèrent pas.
  %w[pending corrupted rejected deleted unknown].each do |state|
    it "fails as not found, logged under its state, for a #{state} piece" do
      attachment = build(:portail_attachment, state: state)
      delivery = build(:portail_delivery, attachments: [attachment])

      result = nil
      events = capture_semantic_logger_events do
        result = described_class.call(delivery: delivery, id: attachment.id)
      end

      expect(result).to be_failure
      expect(result.error).to eq(:not_found)
      expect(events).to include(be_a_semantic_logger_event(
        level: :info, message: "Pièce non livrable",
        payload_includes: {delivery_id: delivery.id, id: attachment.id, reason: :not_received}
      ))
    end
  end
end
