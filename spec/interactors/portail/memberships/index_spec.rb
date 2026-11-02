# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Memberships::Index do
  it "hands back what the page needs about the organisation's data streams" do
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(build(:portail_subscription_list,
      subscriptions: [build(:portail_subscription, data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique")]))

    result = described_class.call(membership: create(:membership, :local_administrator))

    expect(result).to be_success
    expect(result.data_stream_names).to eq({"CERTDC" => "Certificat de décès électronique"})
    expect(result.subscribed_data_stream_codes).to eq(["CERTDC"])
  end
end
