# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem pour le contenu des pièces : avec sa voisine Deliveries, le seul
# endroit du portail qui nomme `HubApiV1`.
RSpec.describe Portail::HubAPI::Attachments do
  let(:siret) { HubApiV1::Testing::Factories::DEFAULT_SIRET }
  let(:insee_code) { HubApiV1::Testing::Factories::DEFAULT_CODE_INSEE }
  let(:delivery_id) { "94b1b09d-b47f-4480-9b48-93b8b36108f2" }

  describe ".download" do
    it "translates upstream content into portal models" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Attachment).to receive(:download).and_return(
        build_v2_attachment_content(
          attachment: build_v2_attachment(filename: "certificat.pdf", content_type: "application/pdf")
        )
      )

      content = described_class.download(delivery_id: delivery_id, id: "an-id",
        author: "Alex Martin", siret: siret, insee_code: insee_code,
        data_stream_codes: ["CERTDC"], client: client)

      expect(content).to be_a(Portail::Delivery::AttachmentContent)
      # La démarche traverse entière : c'est sur elle que la policy rejoue le bornage.
      expect(content.delivery).to be_a(Portail::Delivery)
      expect(content.delivery.data_stream.code).to eq("CERTDC")
      expect(content.delivery.recipient)
        .to eq(Portail::Delivery::Recipient.new(siret: siret, insee_code: insee_code))
      expect(content.attachment).to be_a(Portail::Delivery::Attachment)
      expect(content.attachment)
        .to have_attributes(filename: "certificat.pdf", content_type: "application/pdf")
      expect(content.body).to be_a(String)
    end

    # Hash complet : un paramètre inattendu doit se voir, et un paramètre PERDU plus encore —
    # `data_stream_codes` omis vaudrait « aucune restriction » en aval.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Attachment).to receive(:download).with(
        delivery_id: delivery_id, id: "an-id", author: "Alex Martin", siret: siret,
        # `code_insee` en amont, `insee_code` chez nous : la couture vit à la frontière.
        code_insee: insee_code, data_stream_codes: ["CERTDC"], client: client
      ).and_return(build_v2_attachment_content)

      described_class.download(delivery_id: delivery_id, id: "an-id", author: "Alex Martin",
        siret: siret, insee_code: insee_code, data_stream_codes: ["CERTDC"], client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Attachment).to receive(:download)
        .with(hash_including(client: shared))
        # Le hash complet est éprouvé dans l'exemple ci-dessus.
        .and_return(build_v2_attachment_content)

      described_class.download(delivery_id: delivery_id, id: "an-id", author: "Alex Martin",
        siret: siret, insee_code: insee_code, data_stream_codes: [])
    end
  end

  # Aucune exception de la gem ne doit survivre à cette couche.
  describe "error translation" do
    # Une panne est un incident, signalé au rapporteur d'erreurs de Rails avec l'exception
    # d'origine ; une inexistence ou un refus n'en est pas un, et un robot qui balaie des URL
    # noierait Sentry.
    #
    # Les deux « non trouvé » se séparent ICI et nulle part ailleurs : le refus du bornage part au
    # CSIRT, la pièce absente d'une démarche légitimement consultée ne fait qu'une ligne de log.
    upstream_errors = {
      "a piece the upstream does not serve" => {
        raised: HubApiV1::V2::AttachmentNotFoundError,
        translated: Portail::HubAPI::AttachmentNotFound, reported: false
      },
      # Sans rapport d'erreur, à la différence des pannes : l'amont ne distingue pas une pièce
      # disparue d'une panne, et signaler chaque occurrence noierait le rapporteur.
      "content the upstream could not serve, for a reason it does not give" => {
        raised: HubApiV1::V2::AttachmentUnavailableError,
        translated: Portail::HubAPI::AttachmentUnavailable, reported: false
      },
      # Comptée par la gem avant de rapatrier l'octet : elle ne doit pas se confondre avec une
      # panne, sur laquelle le portail promettrait « réessayez ».
      "a delivery whose history can take no more events" => {
        raised: HubApiV1::V2::DeliveryEventLimitReachedError,
        translated: Portail::HubAPI::HistoryFull, reported: false
      },
      "a read the upstream perimeter refused" => {
        raised: HubApiV1::V2::DeliveryNotFoundError,
        translated: Portail::HubAPI::NotFound, reported: false
      },
      "an argument the upstream refuses" => {
        raised: HubApiV1::V2::InvalidArgumentError,
        translated: Portail::HubAPI::InvalidRequest, reported: false
      },
      "a transport failure" => {
        raised: HubApiV1::Client::ServerError,
        translated: Portail::HubAPI::Unavailable, reported: true
      },
      "an upstream error of any other family" => {
        raised: HubApiV1::Error,
        translated: Portail::HubAPI::Unavailable, reported: true
      }
    }

    def expect_report(error)
      if error[:reported]
        expect(Rails.error).to receive(:report)
          .with(instance_of(error[:raised]), handled: true)
      else
        expect(Rails.error).not_to receive(:report)
      end
    end

    upstream_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Attachment).to receive(:download)
          .and_raise(error[:raised])
        expect_report(error)

        expect {
          described_class.download(delivery_id: delivery_id, id: "an-id", author: "Alex Martin",
            siret: siret, insee_code: insee_code, data_stream_codes: [])
        }.to raise_error(error[:translated])
      end
    end
  end
end
