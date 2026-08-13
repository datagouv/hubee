# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveriesQuery do
  let(:siret) { "22770001000019" }
  let(:membership) { create(:membership, organization_link: create(:organization_link, siret: siret)) }

  # Le client bouchonné de la gem : aucun HTTP, et surtout aucun format de fil de l'API
  # amont écrit dans ce dépôt public.
  def fake_client
    HubApiV1::Testing::FakeClient.new
      .add_organization(build_organization_record(siret: siret, type: "SI"))
  end

  describe "#call" do
    it "returns the deliveries within the membership organisation perimeter" do
      client = fake_client.add_case(build_delivery)

      result = described_class.new(membership, client: client).call(state: :acknowledged)

      expect(result.deliveries.size).to eq(1)
      expect(result.deliveries.first.number).to eq("DGS-CERTDC-0000000000001-01")
    end

    # Sans client injecté : un périmètre vide ne doit exiger ni appel, ni credentials.
    it "makes no call when the authorised perimeter is empty" do
      expect(HubApiV1::V2::Delivery).not_to receive(:list)

      result = described_class.new(membership).call(data_stream_codes: [])

      expect(result.deliveries).to be_empty
      expect(result.pagination.total).to eq(0)
      expect(result.counts_by_state.values).to all(eq(0))
    end

    it "passes the authorised data stream codes as a filter" do
      allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_delivery_list([]))

      described_class.new(membership, client: fake_client).call(state: :transmitted, data_stream_codes: ["CERTDC"])

      expect(HubApiV1::V2::Delivery).to have_received(:list)
        .with(hash_including(data_stream_codes: ["CERTDC"]))
    end

    it "applies no filter when the authorised perimeter carries none" do
      allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_delivery_list([]))

      described_class.new(membership, client: fake_client).call(state: :transmitted, data_stream_codes: nil)

      expect(HubApiV1::V2::Delivery).to have_received(:list)
        .with(hash_including(data_stream_codes: []))
    end

    it "translates the requested page into an offset" do
      allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_delivery_list([]))

      described_class.new(membership, client: fake_client).call(state: :transmitted, page: 3)

      expect(HubApiV1::V2::Delivery).to have_received(:list)
        .with(hash_including(offset: 50, per_page: 25))
    end

    # Un paramètre d'URL trafiqué ne doit pas produire de décalage négatif.
    it "clamps a page below 1 to the first page" do
      allow(HubApiV1::V2::Delivery).to receive(:list).and_return(build_delivery_list([]))

      described_class.new(membership, client: fake_client).call(state: :transmitted, page: 0)

      expect(HubApiV1::V2::Delivery).to have_received(:list).with(hash_including(offset: 0))
    end
  end
end
