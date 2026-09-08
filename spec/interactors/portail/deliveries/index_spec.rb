# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Index do
  # Le cas standard : un membre habilité. Ses flux sont connus en base, l'amont n'est lu que
  # pour la liste.
  it "hands back the list of the membership and the data streams it may filter on" do
    membership = create(:membership)
    create(:process_access, membership: membership, process_code: "CERTDC")
    list = build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)])
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_return(list)
    expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

    result = described_class.call(membership: membership,
      criteria: Portail::Delivery::Criteria.from_params({statut: "done"}), page: 1)

    expect(result).to be_success
    expect(result.list).to eq(list)
    expect(result.selectable_data_streams).to eq(["CERTDC"])
  end
end
