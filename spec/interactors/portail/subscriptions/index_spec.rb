# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::Index do
  it "hands back the subscriptions of the organisation" do
    subscriptions = build(:portail_subscription_list)
    expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(subscriptions)

    result = described_class.call(membership: create(:membership, :local_administrator))

    expect(result).to be_success
    expect(result.subscriptions).to eq(subscriptions)
  end
end
