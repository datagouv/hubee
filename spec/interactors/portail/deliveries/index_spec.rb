# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Index do
  it "hands back the list of the membership" do
    membership = create(:membership)
    list = build(:portail_delivery_list)
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(list)

    result = described_class.call(membership: membership,
      perimeter: Portail::ReadingPerimeter.unrestricted, state: "done", page: 1)

    expect(result).to be_success
    expect(result.list).to eq(list)
  end
end
