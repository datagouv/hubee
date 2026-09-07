# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Index::FetchList do
  let(:membership) do
    create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure.
  # Hash complet : un paramètre inattendu doit se voir.
  it "asks the upstream for the organisation of the membership, on the requested state and page" do
    deliveries = [build(:portail_delivery_summary)]
    page = build(:portail_delivery_page)
    expect(Portail::HubAPI::Deliveries).to receive(:list).with(
      siret: "22770001000019", insee_code: "77372", state: "transmitted",
      data_stream_codes: [], page: 1, per_page: described_class::PER_PAGE
    ).and_return([deliveries, page])

    result = described_class.call(membership: membership, state: "transmitted", page: 1)

    expect(result).to be_success
    expect(result.deliveries).to eq(deliveries)
    expect(result.page).to eq(page)
  end

  it "passes the habilitated data streams as a filter" do
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Deliveries).to receive(:list).with(
      siret: "22770001000019", insee_code: "77372", state: "acknowledged",
      data_stream_codes: ["CERTDC"], page: 2, per_page: described_class::PER_PAGE
    ).and_return([[], build(:portail_delivery_page)])

    result = described_class.call(membership: membership, state: "acknowledged", page: 2)

    expect(result).to be_success
  end

  # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut « aucun filtre ».
  it "fails without calling the upstream when the membership has no access" do
    member = create(:membership)
    expect(Portail::HubAPI::Deliveries).not_to receive(:list)

    result = described_class.call(membership: member, state: "transmitted", page: 1)

    expect(result).to be_failure
    expect(result.error).to eq(:no_habilitation)
  end

  # `inspect` : le message amont cite le paramètre refusé, qui vient de l'URL.
  it "fails as an invalid request, logged, when the upstream refuses a parameter" do
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      .and_raise(Portail::HubAPI::InvalidRequest, "status: n-importe-quoi")

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, state: "n-importe-quoi", page: 1)
    end

    expect(result).to be_failure
    expect(result.error).to eq(:invalid_request)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: 'Filtre de démarches refusé — "status: n-importe-quoi"'
    ))
  end

  # La panne est signalée par la couche de traduction : ici, seulement le journal et l'échec.
  it "fails as unavailable, logged, when the upstream is failing" do
    expect(Portail::HubAPI::Deliveries).to receive(:list).and_raise(Portail::HubAPI::Unavailable)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, state: "transmitted", page: 1)
    end

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Démarches indisponibles"))
  end
end
