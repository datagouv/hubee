# frozen_string_literal: true

require "rails_helper"

# Les abonnements de l'organisation nomment les flux et disent lesquels elle reçoit. Une
# information d'affichage : sans eux, la liste des agents reste servie.
RSpec.describe Portail::Memberships::Index::ResolveDataStreams do
  it "names the data streams and lists those the organisation subscribes to" do
    membership = create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch)
      .with(siret: "22770001000019", insee_code: "77372")
      .and_return(build(:portail_subscription_list, subscriptions: [
        build(:portail_subscription, data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique"),
        build(:portail_subscription, id: "sub-2", data_stream_code: "SANS_NOM")
      ]))

    result = described_class.call(membership: membership)

    expect(result).to be_success
    expect(result.data_stream_names).to eq({"CERTDC" => "Certificat de décès électronique"})
    expect(result.subscribed_data_stream_codes).to eq(%w[CERTDC SANS_NOM])
  end

  # nil et non une liste vide : rien n'a été vérifié, aucune habilitation ne doit passer pour
  # hors abonnement.
  it "names nothing and leaves the subscribed data streams unknown when the upstream fails" do
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(nil)

    result = described_class.call(membership: create(:membership, :local_administrator))

    expect(result).to be_success
    expect(result.data_stream_names).to eq({})
    expect(result.subscribed_data_stream_codes).to be_nil
  end
end
