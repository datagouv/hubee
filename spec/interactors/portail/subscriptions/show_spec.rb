# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::Show do
  it "hands back the detail found for the membership" do
    membership = create(:membership, :local_administrator)
    detail = build(:portail_subscription_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(detail)

    result = described_class.call(membership: membership, id: "an-id")

    expect(result).to be_success
    expect(result.detail).to eq(detail)
  end
end
