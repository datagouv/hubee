# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem pour le contenu des pièces : les octets ET la trace de leur
# récupération, sous un seul nom. Succès, « non trouvé » et saturation s'éprouvent de bout en bout
# contre le FakeClient ; le contenu non servi et la panne, qu'il ne sait pas produire faute de
# stockage, par bouchon de classe.
RSpec.describe Portail::HubAPI::Attachments do
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }
  let(:attachment_id) { "b7e3c2a0-5d1f-4c8e-9a6b-3f2e1d0c9b8a" }
  # Ce que la trace porte, invariable d'un exemple à l'autre : seuls les exemples qui l'éprouvent
  # citent ces valeurs.
  let(:trace) do
    {filename: "certificat.pdf", author: "Alice Martin", siret: "12345678901234", insee_code: "75056"}
  end

  # Un dossier que le fake sert vraiment, avec la pièce demandée dedans — et servi à
  # l'organisation qui trace : le verbe d'écriture rejoue cette borne avant d'écrire.
  def add_served_case(client)
    client.add_case(build_v2_delivery(id: delivery_id,
      recipient: build_v2_recipient(siret: trace[:siret], code_insee: trace[:insee_code]),
      data_package: build_v2_data_package(attachments: [build_v2_attachment(id: attachment_id)])))
  end

  describe ".download" do
    # Des octets qui ne sont pas de l'UTF-8 valide : un ré-encodage en route se verrait.
    it "returns the bytes of the attachment untouched" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      body = "%PDF-1.7\n\xFF\xFE\x00binaire".b
      client.add_attachment_content(attachment_id: attachment_id, body: body)

      content = described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)

      expect(content).to eq(body)
      expect(content.encoding).to eq(Encoding::BINARY)
    end

    # L'invariant du chantier : les octets reviennent ET l'historique du dossier a gagné la trace.
    # Il s'éprouve contre le fake, pas par bouchon — c'est l'écriture réelle qui compte.
    it "records the retrieval in the history of the delivery" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)

      described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)

      history = HubApiV1::V2::Delivery.find(id: delivery_id, siret: trace[:siret],
        code_insee: trace[:insee_code], client: client).events
      expect(history.last).to have_attributes(event_type: :"attachment.downloaded",
        content: "certificat.pdf", author: "Alice Martin")
    end

    # Hash complet : un paramètre inattendu doit se voir.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Attachment).to receive(:download).with(
        delivery_id: delivery_id, id: attachment_id, client: client
      ).and_return("octets".b)
      # `notify: false` est une décision, pas un défaut hérité : elle se lit au site d'appel.
      expect(HubApiV1::V2::Delivery).to receive(:record_attachment_download).with(
        id: delivery_id, filename: "certificat.pdf", author: "Alice Martin",
        siret: "12345678901234", code_insee: "75056", notify: false, client: client
      ).and_return(build_v2_event)

      described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Attachment).to receive(:download).with(
        delivery_id: delivery_id, id: attachment_id, client: shared
      ).and_return("octets".b)
      # `hash_including` : le hash complet est éprouvé par l'exemple précédent ; celui-ci ne porte
      # que sur le client servi par défaut.
      expect(HubApiV1::V2::Delivery).to receive(:record_attachment_download)
        .with(hash_including(client: shared)).and_return(build_v2_event)

      described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
    end

    # « Pas de trace, pas de fichier » : l'écriture refusée, l'appelant n'obtient rien. Le dossier
    # plein est un état durable de l'amont, pas un incident — rien ne part vers la supervision.
    it "serves nothing when the history of the delivery is full" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      client.saturate_case(delivery_id)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id, **trace, client: client)
      }.to raise_error(Portail::HubAPI::HistoryFull)
    end

    # L'ordre est le contrat : sans octets, rien à tracer — une pièce que l'amont ne sert pas ne
    # doit pas consommer un des emplacements d'événements du dossier.
    it "writes no trace when the content itself could not be served" do
      use_hub_api_fake_client
      stub_hub_api_v2_attachment_unavailable(attachment_id)
      expect(HubApiV1::V2::Delivery).not_to receive(:record_attachment_download)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
      }.to raise_error(Portail::HubAPI::ContentUnavailable)
    end

    # Rien n'est bouchonné : c'est le vrai « non trouvé » de l'amont qui doit se produire.
    it "lets an attachment the delivery does not carry reach the upstream refusal, unreported" do
      client = HubApiV1::Testing::FakeClient.new
      add_served_case(client)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.download(delivery_id: delivery_id, id: "c9d8e7f6-1a2b-4c3d-8e4f-5a6b7c8d9e0f",
          **trace, client: client)
      }.to raise_error(Portail::HubAPI::NotFound)
    end

    it "lets an identifier that is not a UUID reach the upstream refusal before any call" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.download(delivery_id: delivery_id, id: "..", **trace, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests).to be_empty
    end

    # Le seul signal d'une panne de la route de contenu, que l'amont confond avec une pièce
    # purgée : une ligne au message stable, comptable en agrégat, sans rapport d'erreur.
    it "logs an unserved content with what locates it, unreported" do
      use_hub_api_fake_client
      stub_hub_api_v2_attachment_unavailable(attachment_id)
      expect(Rails.logger).to receive(:warn).with("Contenu de pièce non servi par l'amont",
        delivery_id: delivery_id, attachment_id: attachment_id)

      expect {
        described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
      }.to raise_error(Portail::HubAPI::ContentUnavailable)
    end
  end

  # Aucune exception de la gem ne doit survivre à cette couche. Seule la panne est signalée : un
  # robot qui balaie des adresses ne doit pas noyer la supervision.
  describe "error translation of the content" do
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
          described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
        }.to raise_error(error[:translated])
      end
    end
  end

  # L'écriture a son propre rescue, et ses propres refus : ce qui survient APRÈS les octets se
  # traduit comme ce qui survient avant, sans quoi une panne de la trace passerait pour un fichier
  # absent.
  describe "error translation of the trace" do
    trace_errors = {
      "a delivery whose history is full" => {
        raised: HubApiV1::V2::DeliveryEventLimitReachedError, translated: Portail::HubAPI::HistoryFull,
        reported: false
      },
      # La garde de périmètre que le verbe rejoue avant d'écrire : le dossier a disparu, ou n'a
      # jamais été celui de cette organisation.
      "a delivery the upstream refuses to serve" => {
        raised: HubApiV1::V2::DeliveryNotFoundError, translated: Portail::HubAPI::NotFound, reported: false
      },
      "a trace the upstream refuses before any call" => {
        raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest, reported: false
      },
      "a transport failure on the write" => {
        raised: HubApiV1::Client::Error, translated: Portail::HubAPI::Unavailable, reported: true
      }
    }

    trace_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Attachment).to receive(:download).and_return("octets".b)
        expect(HubApiV1::V2::Delivery).to receive(:record_attachment_download).and_raise(error[:raised])
        if error[:reported]
          expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
        else
          expect(Rails.error).not_to receive(:report)
        end

        expect {
          described_class.download(delivery_id: delivery_id, id: attachment_id, **trace)
        }.to raise_error(error[:translated])
      end
    end
  end
end
