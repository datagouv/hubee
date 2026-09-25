# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Archives::Show::EnsureReceivedAttachments do
  it "lets through a deposit with at least one received piece" do
    delivery = build(:portail_delivery, attachments: [
      build(:portail_attachment, state: "pending"),
      build(:portail_attachment, state: "received")
    ])

    expect(described_class.call(delivery: delivery)).to be_success
  end

  # Ce qui n'a rien à remettre se voit dans l'inventaire : aucun appel amont n'a lieu ici.
  it "fails as not found, logged under its reason, when no piece of the deposit is received" do
    delivery = build(:portail_delivery, attachments: %w[pending corrupted rejected deleted].map { |state|
      build(:portail_attachment, state: state)
    })

    result = nil
    events = capture_semantic_logger_events { result = described_class.call(delivery: delivery) }

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Archive non livrable",
      payload_includes: {delivery_id: delivery.id, reason: :no_received_attachment}
    ))
  end

  it "fails as not found for a deposit without any piece" do
    result = described_class.call(delivery: build(:portail_delivery, attachments: []))

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
  end
end
