# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Archives::Show do
  let(:membership) do
    build(:membership, agent: create(:agent, first_name: "Alice", last_name: "Martin"),
      organization_link: build(:organization_link, siret: "12345678901234", insee_code: "75056"))
  end

  # Seules les pièces reçues passent de la vérification à l'archive.
  it "archives the received pieces of the deposit, and only them" do
    client = use_hub_api_fake_client
    received = build(:portail_attachment, id: "a1111111-1111-1111-1111-111111111111", filename: "certificat.pdf")
    pending = build(:portail_attachment, id: "b2222222-2222-2222-2222-222222222222", state: "pending")
    delivery = build(:portail_delivery, attachments: [received, pending])
    client.add_case(build_v2_delivery(id: delivery.id,
      recipient: build_v2_recipient(siret: "12345678901234", code_insee: "75056"),
      data_package: build_v2_data_package(attachments: [build_v2_attachment(id: received.id),
        build_v2_attachment(id: pending.id, state: :pending)])))

    result = described_class.call(delivery: delivery, membership: membership)

    expect(result).to be_success
    names = Zip::File.open(result.archive.path) { |zip| zip.entries.map(&:name) }
    expect(names).to eq(["#{File.basename(result.archive_filename, ".zip")}/certificat.pdf"])
    expect(client.requests_to("#{HubApiV1::Case::PATH}/#{delivery.id}/attachments/#{pending.id}")).to be_empty
  ensure
    result&.archive&.close!
  end

  it "fails as not found, without asking anything of the upstream, when no piece is received" do
    client = use_hub_api_fake_client

    result = described_class.call(
      delivery: build(:portail_delivery, attachments: [build(:portail_attachment, state: "rejected")]),
      membership: membership
    )

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(client.requests).to be_empty
  end
end
