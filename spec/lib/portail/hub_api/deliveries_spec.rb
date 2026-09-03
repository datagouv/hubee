# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem : le seul spec du portail qui nomme `HubApiV1` et utilise ses
# factories et son client bouchonné.
RSpec.describe Portail::HubAPI::Deliveries do
  let(:siret) { HubApiV1::Testing::Factories::DEFAULT_SIRET }
  let(:insee_code) { HubApiV1::Testing::Factories::DEFAULT_CODE_INSEE }

  describe ".list" do
    # Deux démarches aux valeurs distinctes : une traduction qui recopierait la première
    # passerait un test à une seule démarche.
    it "translates an upstream page into portal models" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)
      client.add_case(build_v2_delivery(
        id: "0a11c2f4-0000-4000-8000-000000000044", number: "DGS-CERTDC-0000000000002-01"
      ))

      result = described_class.list(siret: siret, insee_code: insee_code, state: "acknowledged",
        data_stream_codes: [], page: 1, per_page: 25, client: client)

      expect(result).to be_a(Portail::DeliveryList)
      expect(result.deliveries).to all(be_a(Portail::DeliverySummary))
      expect(result.deliveries.map(&:number)).to contain_exactly(
        "DGS-CERTDC-0000000000001-01", "DGS-CERTDC-0000000000002-01"
      )
      expect(result.deliveries.first).to have_attributes(state: "acknowledged")
      expect(result.deliveries.first.data_stream.code).to eq("CERTDC")
      expect(result.pagination).to have_attributes(current_page: 1, total_pages: 1, total: 2)
    end

    # Hash complet : un paramètre inattendu doit se voir.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted,
        data_stream_codes: ["CERTDC"], offset: 50, per_page: 25, client: client
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: ["CERTDC"], page: 3, per_page: 25, client: client)
    end

    # Passer `nil` à la gem remplacerait son client par rien.
    it "leaves the upstream client out when none is injected" do
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted,
        data_stream_codes: [], offset: 0, per_page: 25
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: [], page: 1, per_page: 25)
    end

    # Rien n'est bouchonné : c'est le vrai refus de l'amont qui doit se produire.
    it "lets an unknown state reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "n-importe-quoi",
          data_stream_codes: [], page: 1, per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    it "lets an unusable page reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
          data_stream_codes: [], page: "n-importe-quoi", per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    # Les compteurs donnent au portail l'ordre des états : il doit survivre à la traduction.
    it "carries the state counts complete, ordered and in the portal spelling" do
      client = HubApiV1::Testing::FakeClient.new

      result = described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: [], page: 1, per_page: 25, client: client)

      expect(result.counts_by_state.keys).to eq(
        %w[transmitted acknowledged in_progress awaiting_documents done refused closed integration_error]
      )
      expect(result.counts_by_state.values).to all(be_a(Integer))
    end
  end

  describe ".find" do
    it "translates an upstream delivery into a portal delivery, applicant included" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result).to be_a(Portail::Delivery)
      expect(result).to have_attributes(
        number: "DGS-CERTDC-0000000000001-01", state: "acknowledged"
      )
      expect(result.data_stream.code).to eq("CERTDC")
      expect(result.applicant).to be_a(Portail::Applicant)
      expect(result.applicant.full_name).to eq("George DUBOIS")
    end

    it "renders no applicant when the upstream serves none" do
      expect(HubApiV1::V2::Delivery).to receive(:find)
        .and_return(build_v2_delivery(data_package: nil))

      result = described_class.find(id: "an-id", siret: siret, insee_code: insee_code)

      expect(result).to be_a(Portail::Delivery)
      expect(result.applicant).to be_nil
    end

    # L'état arrive en Symbol et doit ressortir en String, comme celui de la démarche.
    it "translates the deposit attachments into portal attachments" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result.attachments).to all(be_a(Portail::Attachment))
      expect(result.attachments.first).to have_attributes(
        filename: "certificat.pdf", content_type: "application/pdf",
        byte_size: 1024, kind: "VA_CertificatdeDeces", state: "received"
      )
    end

    # Liste vide et non nil : l'écran compte les pièces sans se demander si le conteneur existe.
    it "yields no attachment when the upstream serves no data package" do
      expect(HubApiV1::V2::Delivery).to receive(:find)
        .and_return(build_v2_delivery(data_package: nil))

      result = described_class.find(id: "an-id", siret: siret, insee_code: insee_code)

      expect(result.attachments).to eq([])
    end

    it "translates the events into portal events, their own attachments included" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery(events: [
        build_v2_event(si_comment: "retry #2", attachments: [build_v2_attachment(
          id: "a2222222-2222-2222-2222-222222222222", filename: "complement.pdf"
        )])
      ]))

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result.events).to all(be_a(Portail::Event))
      expect(result.events.first).to have_attributes(
        event_type: "delivery.state_changed", author: "George DUBOIS",
        content: "Dossier pris en charge", si_comment: "retry #2"
      )
      expect(result.events.first.attachments.first)
        .to have_attributes(filename: "complement.pdf", state: "received")
    end

    # Les états de la metadata suivent la même conversion que partout ailleurs.
    it "renders the event metadata states in the portal spelling" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery(events: [build_v2_event]))

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result.events.first.metadata)
        .to eq({from_state: "transmitted", to_state: "acknowledged"})
    end

    it "leaves a non-state metadata value untouched" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery(events: [build_v2_event(event_type: :"message.created")]))

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result.events.first.metadata).to eq({internal: false})
    end

    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Delivery).to receive(:find).with(
        id: "an-id", siret: siret, code_insee: insee_code, client: client
      ).and_return(build_v2_delivery)

      described_class.find(id: "an-id", siret: siret, insee_code: insee_code, client: client)
    end
  end

  describe ".empty_list" do
    # Mêmes clés, même ordre et même graphie qu'une vraie page : c'est d'elle que vient
    # l'ordre des états pour l'agent habilité sur aucun flux.
    it "builds a complete empty page without calling the upstream" do
      expect(HubApiV1::V2::Delivery).not_to receive(:list)

      result = described_class.empty_list(per_page: 25)

      expect(result).to be_a(Portail::DeliveryList)
      expect(result.deliveries).to be_empty
      expect(result.pagination).to have_attributes(current_page: 1, total_pages: 1)
      expect(result.counts_by_state.keys).to eq(
        %w[transmitted acknowledged in_progress awaiting_documents done refused closed integration_error]
      )
      expect(result.counts_by_state.values).to all(eq(0))
    end
  end

  # Aucune exception de la gem ne doit survivre à cette couche.
  describe "error translation" do
    upstream_errors = {
      "a delivery the upstream does not serve" => {
        raised: HubApiV1::V2::DeliveryNotFoundError, translated: Portail::HubAPI::NotFound
      },
      "an argument the upstream refuses" => {
        raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest
      },
      "a transport failure" => {
        raised: HubApiV1::Client::ServerError, translated: Portail::HubAPI::Unavailable
      },
      "an upstream error of any other family" => {
        raised: HubApiV1::Error, translated: Portail::HubAPI::Unavailable
      }
    }

    upstream_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} on list for #{situation}" do
        expect(HubApiV1::V2::Delivery).to receive(:list).and_raise(error[:raised])

        expect {
          described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
            data_stream_codes: [], page: 1, per_page: 25)
        }.to raise_error(error[:translated])
      end

      it "raises #{error[:translated].name.demodulize} on find for #{situation}" do
        expect(HubApiV1::V2::Delivery).to receive(:find).and_raise(error[:raised])

        expect {
          described_class.find(id: "an-id", siret: siret, insee_code: insee_code)
        }.to raise_error(error[:translated])
      end
    end
  end
end
