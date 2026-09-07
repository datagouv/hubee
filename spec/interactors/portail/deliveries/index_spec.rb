# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Index do
  it "hands back the deliveries of the membership, and the page that situates them" do
    membership = create(:membership, :local_administrator)
    deliveries = [build(:portail_delivery_summary)]
    page = build(:portail_delivery_page)
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_return([deliveries, page])

    result = described_class.call(membership: membership, state: "done", page: 1)

    expect(result).to be_success
    expect(result.deliveries).to eq(deliveries)
    expect(result.page).to eq(page)
  end
end
