# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show::VerifyContentSize do
  let(:delivery) { build(:portail_delivery) }
  let(:attachment) { build(:portail_attachment, byte_size: 6) }

  it "lets a content of the announced size through, untouched" do
    result = described_class.call(delivery: delivery, attachment: attachment, body: "octets".b)

    expect(result).to be_success
    expect(result.body).to eq("octets".b)
  end

  # Des octets nus, sans rien qui les rattache à la pièce : la taille annoncée, exacte pour une
  # pièce reçue, est le seul témoin qu'ils sont les siens. Un écart est un incident amont.
  it "fails, logged and reported with both sizes, when the content has not the announced size" do
    expect(Rails.error).to receive(:report).with(
      instance_of(described_class::UnexpectedSize), handled: true,
      context: {
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", attachment_id: "a1111111-1111-1111-1111-111111111111",
        expected: 6, received: 5
      }
    )

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(delivery: delivery, attachment: attachment, body: "octet".b)
    end

    expect(result).to be_failure
    expect(result.error).to eq(:unexpected_size)
    expect(events).to include(be_a_semantic_logger_event(
      level: :error, message: "Contenu de pièce d'une taille inattendue",
      payload_includes: {
        delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111",
        expected: 6, received: 5
      }
    ))
  end
end
