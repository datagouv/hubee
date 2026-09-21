# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show do
  it "hands back the content of a received piece" do
    delivery = build(:portail_delivery)
    agent = create(:agent, first_name: "Alice", last_name: "Martin")
    membership = build(:membership, agent: agent,
      organization_link: build(:organization_link, siret: "12345678901234", insee_code: "75056"))
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(delivery_id: delivery.id, id: "a1111111-1111-1111-1111-111111111111",
        filename: "certificat.pdf", author: "Alice Martin", siret: "12345678901234", insee_code: "75056")
      .and_return("octets".b)

    result = described_class.call(delivery: delivery, attachment: delivery.attachments.first,
      membership: membership, agent: agent)

    expect(result).to be_success
    expect(result.body).to eq("octets".b)
  end
end
