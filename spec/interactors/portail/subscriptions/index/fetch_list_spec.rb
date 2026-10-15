# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::Index::FetchList do
  let(:membership) do
    create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  # Le couple vient du rattachement : pris ailleurs, il ouvrirait une autre structure.
  it "reads the subscriptions of the organisation of the membership" do
    subscriptions = build(:portail_subscription_list)
    expect(Portail::HubAPI::Subscriptions).to receive(:list)
      .with(siret: "22770001000019", insee_code: "77372").and_return(subscriptions)

    result = described_class.call(membership: membership)

    expect(result).to be_success
    expect(result.subscriptions).to eq(subscriptions)
  end

  it "fails as unavailable, logged, when the upstream fails" do
    expect(Portail::HubAPI::Subscriptions).to receive(:list).and_raise(Portail::HubAPI::Unavailable)

    result = nil
    events = capture_semantic_logger_events { result = described_class.call(membership: membership) }

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Abonnements indisponibles"))
  end
end
