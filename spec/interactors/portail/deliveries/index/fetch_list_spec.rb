# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Index::FetchList do
  let(:membership) do
    create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  def criteria(**params) = Portail::Delivery::Criteria.from_params(params)

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure. Le
  # filtre de flux est celui résolu par l'étape précédente. Hash complet : un paramètre inattendu
  # doit se voir.
  it "asks the upstream for the organisation of the membership, on the resolved filter, criteria and page" do
    list = build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)])
    expect(Portail::HubAPI::Deliveries).to receive(:list).with(
      siret: "22770001000019", insee_code: "77372", state: "transmitted", data_stream_codes: ["CERTDC"],
      transmitted_from: nil, transmitted_to: nil, sort: "transmitted_at", direction: "desc",
      page: 1, per_page: described_class::PER_PAGE
    ).and_return(list)

    result = described_class.call(membership: membership, criteria: criteria, requested_data_streams: ["CERTDC"], page: 1)

    expect(result).to be_success
    expect(result.list).to eq(list)
  end

  it "passes the state, the period, the sort and the page along, as the URL says them" do
    expect(Portail::HubAPI::Deliveries).to receive(:list).with(
      siret: "22770001000019", insee_code: "77372", state: "done", data_stream_codes: [],
      transmitted_from: "2026-08-01", transmitted_to: "2026-08-31", sort: "updated_at", direction: "asc",
      page: 2, per_page: described_class::PER_PAGE
    ).and_return(build(:portail_delivery_list))

    result = described_class.call(membership: membership,
      criteria: criteria(statut: "done", du: "2026-08-01", au: "2026-08-31", tri: "updated_at", ordre: "asc"),
      requested_data_streams: [], page: 2)

    expect(result).to be_success
  end

  # `inspect` : le message amont cite le paramètre refusé, qui vient de l'URL.
  it "fails as an invalid request, logged, when the upstream refuses a parameter" do
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      .and_raise(Portail::HubAPI::InvalidRequest, "status: n-importe-quoi")

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, criteria: criteria(statut: "n-importe-quoi"),
        requested_data_streams: [], page: 1)
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
      result = described_class.call(membership: membership, criteria: criteria, requested_data_streams: [], page: 1)
    end

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Démarches indisponibles"))
  end
end
