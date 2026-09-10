# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Attachments::Show do
  it "hands back the content fetched for the membership" do
    membership = create(:membership)
    create(:process_access, membership: membership, process_code: "CERTDC")
    content = build(:portail_attachment_content)
    expect(Portail::HubAPI::Attachments).to receive(:download).and_return(content)

    result = described_class.call(membership: membership, agent: create(:agent),
      delivery_id: "a-delivery", id: "an-id")

    expect(result).to be_success
    expect(result.content).to eq(content)
  end
end
