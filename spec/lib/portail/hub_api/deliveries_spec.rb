# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem : c'est le SEUL spec du portail qui a le droit de nommer
# `HubApiV1`, et le seul qui utilise ses factories et son client bouchonné. Partout ailleurs
# le portail ne connaît que ses propres modèles — c'est ce que cette couche achète.
RSpec.describe Portail::HubAPI::Deliveries do
  let(:siret) { HubApiV1::Testing::Factories::DEFAULT_SIRET }
  let(:insee_code) { HubApiV1::Testing::Factories::DEFAULT_CODE_INSEE }

  describe ".list" do
    # Le chemin complet, sans mock sur la surface de la gem : ce que le FakeClient sert
    # traverse la gem puis la traduction, et ressort en modèles du portail.
    it "translates an upstream page into portal models" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_case(build_v2_delivery)

      result = described_class.list(siret: siret, insee_code: insee_code, state: "acknowledged",
        data_stream_codes: [], page: 1, per_page: 25, client: client)

      expect(result).to be_a(Portail::DeliveryList)
      expect(result.deliveries).to all(be_a(Portail::DeliverySummary))
      expect(result.deliveries.first).to have_attributes(
        number: "DGS-CERTDC-0000000000001-01", state: "acknowledged"
      )
      expect(result.deliveries.first.data_stream.code).to eq("CERTDC")
      expect(result.pagination).to have_attributes(current_page: 1, total_pages: 1)
    end

    # Le canal des entrées : le portail parle en `insee_code` et en pages, l'amont attend
    # `code_insee` et un décalage. Hash complet — un paramètre inattendu doit se voir.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted,
        data_stream_codes: ["CERTDC"], offset: 50, per_page: 25, client: client
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: ["CERTDC"], page: 3, per_page: 25, client: client)
    end

    # Sans client injecté, la gem résout le sien à l'intérieur : le lui passer à nil le
    # remplacerait par rien et couperait le chemin nominal.
    it "leaves the upstream client out when none is injected" do
      expect(HubApiV1::V2::Delivery).to receive(:list).with(
        siret: siret, code_insee: insee_code, state: :transmitted,
        data_stream_codes: [], offset: 0, per_page: 25
      ).and_return(build_v2_delivery_list([]))

      described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
        data_stream_codes: [], page: 1, per_page: 25)
    end

    # Ces deux exemples ne bouchonnent RIEN : c'est le vrai refus de l'amont qui doit se
    # produire, sinon ils ne prouvent que notre traduction d'un refus imaginaire. Ils tombent
    # donc aussi bien si l'amont cesse de valider avant réseau que si le portail réintroduit
    # une garde qui rattrape le paramètre avant lui.
    it "lets an unknown state reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "n-importe-quoi",
          data_stream_codes: [], page: 1, per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    # Une page trafiquée produit un décalage négatif, que l'amont refuse : le refus remonte à
    # l'agent plutôt que de réinitialiser son filtre en silence.
    it "lets an unusable page reach the upstream refusal" do
      client = HubApiV1::Testing::FakeClient.new

      expect {
        described_class.list(siret: siret, insee_code: insee_code, state: "transmitted",
          data_stream_codes: [], page: "n-importe-quoi", per_page: 25, client: client)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end

    # Les compteurs donnent au portail l'ordre des états, et lui seul : cet ordre doit donc
    # survivre à la traduction, en même temps que la graphie.
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

    # Le demandeur vient du paquet de données, et l'amont peut le servir sans. Sans cet
    # exemple, la branche qui rend `applicant` nul n'est jamais empruntée.
    it "renders no applicant when the upstream serves none" do
      expect(HubApiV1::V2::Delivery).to receive(:find)
        .and_return(build_v2_delivery(data_package: nil))

      result = described_class.find(id: "an-id", siret: siret, insee_code: insee_code)

      expect(result).to be_a(Portail::Delivery)
      expect(result.applicant).to be_nil
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
    # Le portail court-circuite l'appel quand l'agent n'est habilité sur aucun flux ; la liste
    # vide reste construite ici pour que l'ordre des états vienne toujours du même endroit.
    it "builds a complete empty page without calling the upstream" do
      expect(HubApiV1::V2::Delivery).not_to receive(:list)

      result = described_class.empty_list(per_page: 25)

      expect(result).to be_a(Portail::DeliveryList)
      expect(result.deliveries).to be_empty
      expect(result.pagination).to have_attributes(current_page: 1, total_pages: 1)
      # Mêmes clés, même ordre et même graphie qu'une vraie page : c'est cette liste-ci que
      # voit l'agent habilité sur aucun flux, et c'est d'elle que viendrait l'ordre des onglets.
      expect(result.counts_by_state.keys).to eq(
        %w[transmitted acknowledged in_progress awaiting_documents done refused closed integration_error]
      )
      expect(result.counts_by_state.values).to all(eq(0))
    end
  end

  # Le canal des erreurs : aucune exception de la gem ne doit survivre à cette couche.
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
