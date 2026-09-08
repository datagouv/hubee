# frozen_string_literal: true

require "rails_helper"

# La frontière avec la gem pour les abonnements d'une organisation.
RSpec.describe Portail::HubAPI::Subscriptions do
  let(:siret) { HubApiV1::Testing::Factories::DEFAULT_SIRET }
  let(:insee_code) { HubApiV1::Testing::Factories::DEFAULT_CODE_INSEE }

  describe ".list" do
    # Deux abonnements aux valeurs distinctes : une traduction qui recopierait le premier
    # passerait un test à un seul abonnement. Le mode d'accès arrive en Symbol et ressort en
    # String, comme l'état d'une démarche.
    it "translates the upstream subscriptions into portal models" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_subscription(build_subscription_record(process_code: "CERTDC", access_mode: "PORTAIL"))
      client.add_subscription(build_subscription_record(id: "sub-2", process_code: "AEC",
        access_mode: "API", status: "Inactif"))

      subscriptions = described_class.list(siret: siret, insee_code: insee_code, client: client)

      expect(subscriptions).to be_a(Portail::Subscription::List)
      expect(subscriptions).to all(be_a(Portail::Subscription))
      expect(subscriptions.map { |subscription| subscription.data_stream.code }).to contain_exactly("CERTDC", "AEC")
      expect(subscriptions.find { |subscription| subscription.data_stream.code == "CERTDC" }).to have_attributes(
        id: "550e8400-e29b-41d4-a716-446655440000", read_package: true, create_package: false, access_mode: "portal"
      )
      expect(subscriptions.find { |subscription| subscription.data_stream.code == "AEC" })
        .to have_attributes(read_package: false, access_mode: "api")
    end

    # Un canal non renseigné en amont reste inconnu ici : « » ferait croire à une valeur.
    it "leaves an unset access mode unknown" do
      client = HubApiV1::Testing::FakeClient.new
      client.add_subscription(build_subscription_record(access_mode: nil))

      subscriptions = described_class.list(siret: siret, insee_code: insee_code, client: client)

      expect(subscriptions.first).to have_attributes(read_package: true, access_mode: nil)
      expect(subscriptions.first).not_to be_readable_via_portal
    end

    # Hash complet : la lecture doit rester bornée sur le couple, pas sur le seul SIRET.
    it "sends the portal vocabulary as the upstream keywords" do
      client = HubApiV1::Testing::FakeClient.new
      expect(HubApiV1::V2::Subscription).to receive(:list)
        .with(siret: siret, code_insee: insee_code, client: client).and_return([])

      described_class.list(siret: siret, insee_code: insee_code, client: client)
    end

    it "hands the gem its shared client when none is injected" do
      shared = use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list)
        .with(siret: siret, code_insee: insee_code, client: shared).and_return([])

      described_class.list(siret: siret, insee_code: insee_code)
    end

    # Même politique que les démarches : une panne est un incident signalé, un refus non.
    it "raises Unavailable, reported, on a transport failure" do
      use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list).and_raise(HubApiV1::Client::ServerError)
      expect(Rails.error).to receive(:report).with(instance_of(HubApiV1::Client::ServerError), handled: true)

      expect {
        described_class.list(siret: siret, insee_code: insee_code)
      }.to raise_error(Portail::HubAPI::Unavailable)
    end

    it "raises InvalidRequest, not reported, on an argument the upstream refuses" do
      use_hub_api_fake_client
      expect(HubApiV1::V2::Subscription).to receive(:list).and_raise(HubApiV1::V2::InvalidArgumentError)
      expect(Rails.error).not_to receive(:report)

      expect {
        described_class.list(siret: siret, insee_code: insee_code)
      }.to raise_error(Portail::HubAPI::InvalidRequest)
    end
  end
end
