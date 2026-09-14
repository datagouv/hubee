# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show do
  it "hands back the piece of the delivery with its content" do
    # La pièce annonce la taille des octets que l'amont sert.
    delivery = build(:portail_delivery, attachments: [build(:portail_attachment, byte_size: 6)])
    expect(Portail::HubAPI::Attachments).to receive(:download)
      .with(delivery_id: delivery.id, id: "a1111111-1111-1111-1111-111111111111")
      .and_return("octets".b)

    result = described_class.call(delivery: delivery, id: "a1111111-1111-1111-1111-111111111111")

    expect(result).to be_success
    expect(result.attachment).to eq(delivery.attachments.first)
    expect(result.body).to eq("octets".b)
  end
end
