# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Index::FetchList do
  let(:membership) do
    create(:membership,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure.
  # Hash complet : un paramètre inattendu doit se voir.
  it "asks the upstream for the organisation of the membership, on the first page of the default state" do
    list = build(:portail_delivery_list)
    expect(Portail::HubAPI::Deliveries).to receive(:list).with(
      siret: "22770001000019", insee_code: "77372", state: "transmitted",
      data_stream_codes: [], page: 1, per_page: described_class::PER_PAGE
    ).and_return(list)

    result = described_class.call(membership: membership,
      perimeter: Portail::ReadingPerimeter.unrestricted, state: nil, page: nil)

    expect(result).to be_success
    expect(result.list).to eq(list)
    expect(result.state).to eq("transmitted")
  end

  it "passes the requested state and page, and the habilitated data streams as a filter" do
    expect(Portail::HubAPI::Deliveries).to receive(:list).with(
      siret: "22770001000019", insee_code: "77372", state: "acknowledged",
      data_stream_codes: ["CERTDC"], page: 2, per_page: described_class::PER_PAGE
    ).and_return(build(:portail_delivery_list))

    result = described_class.call(membership: membership,
      perimeter: Portail::ReadingPerimeter.limited_to(["CERTDC"]), state: "acknowledged", page: 2)

    expect(result).to be_success
    expect(result.state).to eq("acknowledged")
  end

  # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut « aucun filtre ».
  it "fails without calling the upstream when the membership has no access" do
    expect(Portail::HubAPI::Deliveries).not_to receive(:list)

    result = described_class.call(membership: membership,
      perimeter: Portail::ReadingPerimeter.none, state: nil, page: nil)

    expect(result).to be_failure
    expect(result.error).to eq(:no_habilitation)
  end

  # Un robot qui balaie des URL noierait Sentry sous des refus normaux. `inspect` : le message
  # amont cite le paramètre refusé, qui vient de l'URL.
  it "fails as an invalid request, logged and without alert, when the upstream refuses a parameter" do
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      .and_raise(Portail::HubAPI::InvalidRequest, "status: n-importe-quoi")
    expect(Rails.logger).to receive(:info).with('Filtre de démarches refusé — "status: n-importe-quoi"')
    expect(Sentry).not_to receive(:capture_exception)

    result = described_class.call(membership: membership,
      perimeter: Portail::ReadingPerimeter.unrestricted, state: "n-importe-quoi", page: nil)

    expect(result).to be_failure
    expect(result.error).to eq(:invalid_request)
  end

  # Une panne est un incident : quelqu'un est réveillé.
  it "fails as unavailable and reports the outage when the upstream is failing" do
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::Unavailable)
    expect(Sentry).to receive(:capture_exception).with(Portail::HubAPI::Unavailable)

    result = described_class.call(membership: membership,
      perimeter: Portail::ReadingPerimeter.unrestricted, state: nil, page: nil)

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
  end
end
