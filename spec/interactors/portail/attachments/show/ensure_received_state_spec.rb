# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show::EnsureReceivedState do
  let(:delivery) { build(:portail_delivery) }

  it "lets a received piece through" do
    result = described_class.call(delivery: delivery, attachment: build(:portail_attachment, state: "received"))

    expect(result).to be_success
  end

  # Aucun appel amont n'a lieu ici : ce qui n'est pas livrable se voit dans l'inventaire.
  %w[pending corrupted rejected deleted unknown].each do |state|
    it "fails as not found, logged under its reason, for a #{state} piece" do
      attachment = build(:portail_attachment, state: state)

      result = nil
      events = capture_semantic_logger_events do
        result = described_class.call(delivery: delivery, attachment: attachment)
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
