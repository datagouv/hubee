# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::Credentials::Create do
  it "hands back the credentials and records the consultation" do
    membership = create(:membership, :local_administrator)
    credentials = Portail::Subscription::Credentials.new(client_id: "client-42", client_secret: "s3cr3t")
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(credentials)

    result = described_class.call(membership: membership, subscription: build(:portail_subscription, access_mode: "api"))

    expect(result).to be_success
    expect(result.credentials).to eq(credentials)
    expect(Event.sole.event_type).to eq("subscription.credentials_revealed")
  end

  # Lire, puis tracer : une trace sans lecture réussie mentirait.
  it "records nothing when the credentials could not be read" do
    membership = create(:membership, :local_administrator)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    result = described_class.call(membership: membership, subscription: build(:portail_subscription, access_mode: "api"))

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(Event.count).to eq(0)
  end
end
