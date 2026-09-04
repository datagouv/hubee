# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Show do
  it "hands back the delivery found for the membership" do
    membership = create(:membership)
    delivery = build(:portail_delivery)
    expect(Portail::HubAPI::Deliveries).to receive(:find).and_return(delivery)

    result = described_class.call(membership: membership, id: "an-id")

    expect(result).to be_success
    expect(result.delivery).to eq(delivery)
  end
end
