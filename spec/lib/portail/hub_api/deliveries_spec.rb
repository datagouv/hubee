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

      list = described_class.list(siret: siret, insee_code: insee_code, state: "acknowledged",
        data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
        sort: "transmitted_at", direction: "desc", page: 1, per_page: 25, client: client)

      expect(list).to be_a(Portail::Delivery::List)
      expect(list.deliveries).to all(be_a(Portail::Delivery::Summary))
      expect(list.deliveries.map(&:number)).to contain_exactly(
        "DGS-CERTDC-0000000000001-01", "DGS-CERTDC-0000000000002-01"
      )
      expect(list.deliveries.first).to have_attributes(state: "acknowledged")
      expect(list.deliveries.first.data_stream.code).to eq("CERTDC")
      # `code_insee` en amont, `insee_code` ici : la couture vit à la frontière.
      expect(list.deliveries.first.recipient)
        .to eq(Portail::Delivery::Recipient.new(siret: siret, insee_code: insee_code))
      # La page à part des démarches : ce qui situe la liste ne transporte pas ce qu'elle contient.
      expect(list.page).to be_a(Portail::Delivery::Page)
      expect(list.page.pagination).to have_attributes(current_page: 1, total_pages: 1, total: 2)
    end

    # Hash complet : un paramètre inattendu doit se voir.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted,
        data_stream_codes: ["CERTDC"], transmitted_from: nil, transmitted_to: nil,
        sort: :transmitted_at, direction: :desc, offset: 50, per_page: 25, client: client
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: ["CERTDC"], transmitted_from: nil, transmitted_to: nil,
        sort: "transmitted_at", direction: "desc", page: 3, per_page: 25, client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted,
        data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
        sort: :transmitted_at, direction: :desc, offset: 0, per_page: 25, client: shared
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
        sort: "transmitted_at", direction: "desc", page: 1, per_page: 25)
    end

    # Rien n'est bouchonné : c'est le vrai refus de l'amont qui doit se produire.
    it "lets an unknown state reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "n-importe-quoi",
          data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
          sort: "transmitted_at", direction: "desc", page: 1, per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    it "lets an unusable page reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
          data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
          sort: "transmitted_at", direction: "desc", page: "n-importe-quoi", per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    # L'amont veut des instants, bornes incluses : « jusqu'au 31 » doit couvrir toute la journée
    # du 31, en heure de Paris. Hash complet : la conversion ne doit toucher que les deux bornes.
    it "turns the transmission dates into day boundaries in the application time zone" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted, data_stream_codes: [],
        transmitted_from: Time.zone.local(2026, 8, 1),
        transmitted_to: Time.zone.local(2026, 8, 31).end_of_day,
        sort: :updated_at, direction: :asc, offset: 0, per_page: 25, client: client
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: [], transmitted_from: "2026-08-01", transmitted_to: "2026-08-31",
        sort: "updated_at", direction: "asc", page: 1, per_page: 25, client: client)
    end

    # La date vient de l'URL : hors de la forme AAAA-MM-JJ, hors calendrier ou hors siècle, elle
    # est refusée ici avant tout appel. `Date.iso8601` seul laisserait passer les écritures
    # ordinale, compacte et les années absurdes, et lève une ArgumentError, pas une Date::Error,
    # au-delà de 128 caractères : une URL forgée donnerait un 500.
    it "refuses a transmission date that is not a calendar day in YYYY-MM-DD before any call" do
      client = HubApiV1::Testing::FakeClient.new
      unreadable = ["31/08/2026", "2026-213", "20260801", "2026-02-30", "0000-01-01", "2126-01-01",
        "2026-08-01#{"x" * 200}"]

      unreadable.each do |date|
        expect {
          described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
            data_stream_codes: [], transmitted_from: date, transmitted_to: nil,
            sort: "transmitted_at", direction: "desc", page: 1, per_page: 25, client: client)
        }.to raise_error(Portail::HubAPI::InvalidRequest), date
      end
      expect(client.requests).to be_empty
    end

    it "lets an unknown sort reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
          data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
          sort: "n-importe-quoi", direction: "desc", page: 1, per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    # Les compteurs donnent au portail l'ordre des états : il doit survivre à la traduction.
    it "carries the state counts complete, ordered and in the portal spelling" do
      client = HubApiV1::Testing::FakeClient.new

      list = described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
        sort: "transmitted_at", direction: "desc", page: 1, per_page: 25, client: client)

      expect(list.page.counts_by_state.keys).to eq(
        %w[transmitted acknowledged in_progress awaiting_documents done refused closed integration_error]
      )
      expect(list.page.counts_by_state.values).to all(be_a(Integer))
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
      expect(result.recipient).to eq(Portail::Delivery::Recipient.new(siret: siret, insee_code: insee_code))
      expect(result.applicant).to be_a(Portail::Delivery::Applicant)
      expect(result.applicant.full_name).to eq("George DUBOIS")
    end

    it "renders no applicant when the upstream serves none" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery(data_package: nil))

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result).to be_a(Portail::Delivery)
      expect(result.applicant).to be_nil
    end

    # L'état arrive en Symbol et doit ressortir en String, comme celui de la démarche.
    it "translates the deposit attachments into portal attachments" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

      expect(result.attachments).to all(be_a(Portail::Delivery::Attachment))
      expect(result.attachments.first).to have_attributes(
        filename: "certificat.pdf", content_type: "application/pdf",
        byte_size: 1024, kind: "VA_CertificatdeDeces", state: "received"
      )
    end

    # Liste vide et non nil : l'écran compte les pièces sans se demander si le conteneur existe.
    it "yields no attachment when the upstream serves no data package" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery(data_package: nil))

      result = described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)

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

      expect(result.events).to all(be_a(Portail::Delivery::Event))
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
        id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", siret: siret, code_insee: insee_code, client: client
      ).and_return(build_v2_delivery)

      described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        siret: siret, insee_code: insee_code, client: client)
    end

    # Rien n'est bouchonné : c'est la garde de la gem qui doit refuser, avant tout appel réseau.
    # L'identifiant vient de l'URL : `/demarches/%20` ne doit pas passer pour une panne.
    it "lets a blank identifier reach the upstream refusal before any call" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.find(id: "", siret: siret, insee_code: insee_code, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests).to be_empty
    end

    it "lets an identifier that is not a UUID reach the upstream refusal before any call" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.find(id: "foo", siret: siret, insee_code: insee_code, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
      expect(client.requests).to be_empty
    end
  end

  # Aucune exception de la gem ne doit survivre à cette couche.
  describe "error translation" do
    # Une panne est un incident, signalé au rapporteur d'erreurs de Rails avec l'exception
    # d'origine ; une inexistence ou un refus n'en est pas un, et un robot qui balaie des URL
    # noierait Sentry.
    upstream_errors = {
      "a delivery the upstream does not serve" => {
        raised: HubApiV1::V2::DeliveryNotFoundError, translated: Portail::HubAPI::NotFound, reported: false
      },
      "an argument the upstream refuses" => {
        raised: HubApiV1::V2::InvalidArgumentError, translated: Portail::HubAPI::InvalidRequest, reported: false
      },
      "a transport failure" => {
        raised: HubApiV1::Client::ServerError, translated: Portail::HubAPI::Unavailable, reported: true
      },
      "an upstream error of any other family" => {
        raised: HubApiV1::Error, translated: Portail::HubAPI::Unavailable, reported: true
      }
    }

    def expect_report(error)
      if error[:reported]
        expect(Rails.error).to receive(:report).with(instance_of(error[:raised]), handled: true)
      else
        expect(Rails.error).not_to receive(:report)
      end
    end

    upstream_errors.each do |situation, error|
      it "raises #{error[:translated].name.demodulize} on list for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Delivery).to receive(:list).and_raise(error[:raised])
        expect_report(error)

        expect {
          described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
            data_stream_codes: [], transmitted_from: nil, transmitted_to: nil,
            sort: "transmitted_at", direction: "desc", page: 1, per_page: 25)
        }.to raise_error(error[:translated])
      end

      it "raises #{error[:translated].name.demodulize} on find for #{situation}, reported: #{error[:reported]}" do
        use_hub_api_fake_client
        expect(HubApiV1::V2::Delivery).to receive(:find).and_raise(error[:raised])
        expect_report(error)

        expect {
          described_class.find(id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", siret: siret, insee_code: insee_code)
        }.to raise_error(error[:translated])
      end
    end
  end
end
