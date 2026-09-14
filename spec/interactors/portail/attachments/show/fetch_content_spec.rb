# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show::FetchContent do
  let(:delivery) { build(:portail_delivery) }
  let(:attachment) { build(:portail_attachment) }

  # Les identifiants viennent de l'inventaire servi, jamais de l'URL.
  it "fetches the content of the piece within its delivery" do
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(delivery_id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", id: "a1111111-1111-1111-1111-111111111111")
      .and_return("octets".b)

    result = described_class.call(delivery: delivery, attachment: attachment)

    expect(result).to be_success
    expect(result.body).to eq("octets".b)
  end

  # Le contenu non servi est déjà journalisé par la frontière, la panne déjà signalée : ici,
  # seulement le journal et l'échec, sous un même mode dégradé.
  %w[ContentUnavailable Unavailable].each do |error|
    it "fails as unavailable, logged, when the upstream raises #{error}" do
      expect(Portail::HubAPI::Attachments).to receive(:download)
        .and_raise(Portail::HubAPI.const_get(error))

      result = nil
      events = capture_semantic_logger_events do
        result = described_class.call(delivery: delivery, attachment: attachment)
      end

      expect(result).to be_failure
      expect(result.error).to eq(:unavailable)
      expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Pièce indisponible"))
    end
  end
end
