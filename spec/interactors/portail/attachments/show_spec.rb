# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show do
  it "hands back the content of a received piece" do
    delivery = build(:portail_delivery)
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(delivery_id: delivery.id, id: "a1111111-1111-1111-1111-111111111111")
      .and_return("octets".b)

    result = described_class.call(delivery: delivery, attachment: delivery.attachments.first)

    expect(result).to be_success
    expect(result.body).to eq("octets".b)
  end
end
