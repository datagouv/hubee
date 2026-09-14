# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem pour le contenu des pièces. Succès et « non trouvé » s'éprouvent de
# bout en bout contre le FakeClient ; le contenu non servi et la panne, qu'il ne sait pas produire
# faute de stockage, par bouchon de classe.
RSpec.describe Portail::HubAPI::Attachments do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:attachment_id) { "a1111111-1111-1111-1111-111111111111" }

  describe ".download" do
    # Des octets qui ne sont pas de l'UTF-8 valide : un ré-encodage en route se verrait.
    it "returns the bytes of the attachment untouched" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)
      body = "%PDF-1.7\n\xFF\xFE\x00binaire".b
      client.add_attachment_content(attachment_id: attachment_id, body: body)

      content = described_class.download(delivery_id: delivery_id, id: attachment_id, client: client)

      expect(content).to eq(body)
      expect(content.encoding).to eq(Encoding::BINARY)
    end

    # Hash complet : un paramètre inattendu doit se voir.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Attachment).to receive(:download)
        .with(delivery_id: delivery_id, id: attachment_id, client: client)
        .and_return("octets".b)

      described_class.download(delivery_id: delivery_id, id: attachment_id, client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Attachment).to receive(:download)
        .with(delivery_id: delivery_id, id: attachment_id, client: shared)
        .and_return("octets".b)

      described_class.download(delivery_id: delivery_id, id: attachment_id)
    end

    # Rien n'est bouchonné : c'est le vrai « non trouvé » de l'amont qui doit se produire.
    it "lets an attachment the delivery does not carry reach the upstream refusal, unreported" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.download(delivery_id: delivery_id, id: "a2222222-2222-2222-2222-222222222222",
          client: client)
      }.to raise_error(Portail::HubAPI::NotFound)
    end

    it "lets an identifier that is not a UUID reach the upstream refusal before any call" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.download(delivery_id: delivery_id, id: "..", client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests).to be_empty
    end

    # Le seul signal d'une panne de la route de contenu, que l'amont confond avec une pièce
    # purgée : une ligne au message stable, comptable en agrégat, sans rapport d'erreur.
    it "logs an unserved content with what locates it, unreported" do
      stub_hub_api_v2_attachment_unavailable(attachment_id)
      expect(Rails.logger).to receive(:warn)
        .with("Contenu de pièce non servi par l'amont", delivery_id: delivery_id, attachment_id: attachment_id)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id)
      }.to raise_error(Portail::HubAPI::ContentUnavailable)
    end
  end

  # Aucune exception de la gem ne doit survivre à cette couche. Seule la panne est signalée : un
  # robot qui balaie des adresses ne doit pas noyer la supervision.
  describe "error translation" do
    upstream_errors = {
      "an attachment the upstream does not serve" => {
        raised: HubApiV1::V2::AttachmentNotFoundError, translated: Portail::HubAPI::NotFound, reported: false
      },
      "an identifier the upstream refuses" => {
        raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest, reported: false
      },
      "a content the upstream could not serve" => {
        raised: HubApiV1::V2::AttachmentUnavailableError, translated: Portail::HubAPI::ContentUnavailable,
        reported: false
      },
      # Le compte du portail n'est pas autorisé sur la route : un incident d'exploitation, pas une
      # situation à expliquer à l'agent.
      "a configuration refusal" => {
        raised: HubApiV1::Client::ForbiddenError, translated: Portail::HubAPI::Unavailable, reported: true
      },
      "a transport failure" => {
        raised: HubApiV1::Client::Error, translated: Portail::HubAPI::Unavailable, reported: true
      },
      "an upstream error of any other family" => {
        raised: HubApiV1::Error, translated: Portail::HubAPI::Unavailable, reported: true
      }
    }

    upstream_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Attachment).to receive(:download).and_raise(error[:raised])
        if error[:reported]
          expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
        else
          expect(Rails.error).not_to receive(:report)
        end

        expect {
          described_class.download(delivery_id: delivery_id, id: attachment_id)
        }.to raise_error(error[:translated])
      end
    end
  end
end
