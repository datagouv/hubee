# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::Credentials::Create::FetchCredentials do
  let(:membership) do
    create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure.
  it "puts the credentials served for the membership's organisation in the context" do
    subscription = build(:portail_subscription, id: "sub-1", access_mode: "api")
    credentials = Portail::Subscription::Credentials.new(client_id: "client-42", client_secret: "s3cr3t")
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials)
      .with(id: "sub-1", siret: "22770001000019", insee_code: "77372")
      .and_return(credentials)

    result = described_class.call(membership: membership, subscription: subscription)

    expect(result).to be_success
    expect(result.credentials).to eq(credentials)
  end

  it "fails as not found when the upstream does not know the subscription" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::NotFound)

    result = described_class.call(membership: membership, subscription: build(:portail_subscription, access_mode: "api"))

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
  end

  it "fails as not found when the upstream rejects the identifier" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::InvalidRequest)

    result = described_class.call(membership: membership, subscription: build(:portail_subscription, access_mode: "api"))

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
  end

  it "fails as refused, with the upstream reason, when the upstream refuses to serve them" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials)
      .and_raise(Portail::HubAPI::CredentialsRefused.new(:ambiguous_client))

    result = described_class.call(membership: membership, subscription: build(:portail_subscription, access_mode: "api"))

    expect(result).to be_failure
    expect(result.error).to eq(:refused)
    expect(result.reason).to eq(:ambiguous_client)
  end

  it "fails as unavailable when the upstream is failing" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    result = described_class.call(membership: membership, subscription: build(:portail_subscription, access_mode: "api"))

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
  end
end
