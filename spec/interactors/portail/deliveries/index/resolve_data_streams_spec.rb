# frozen_string_literal: true

require "rails_helper"

# Les flux proposés au filtre et le filtre envoyé à l'amont : le périmètre du rattachement quand
# il en a un, les abonnements de l'organisation en lecture via le portail sinon. Une seule règle
# pour tous, la seconde branche disparaîtra avec les habilitations des administrateurs locaux.
RSpec.describe Portail::Deliveries::Index::ResolveDataStreams do
  def criteria(**params) = Portail::Delivery::Criteria.from_params(params)

  def upstream_subscriptions(*codes)
    build(:portail_subscription_list, subscriptions: codes.map.with_index do |code, index|
      build(:portail_subscription, id: "sub-#{index}", data_stream_code: code)
    end)
  end

  it "offers a habilitated member its data streams, sorted, and filters on them, without calling the upstream" do
    membership = create(:membership)
    create(:process_access, membership: membership, process_code: "CERTDC")
    create(:process_access, membership: membership, process_code: "AEC")
    expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(%w[AEC CERTDC])
    expect(result.requested_data_streams).to contain_exactly("CERTDC", "AEC")
  end

  it "offers a local administrator with named habilitations those alone" do
    membership = create(:membership, :local_administrator)
    create(:process_access, membership: membership, process_code: "CERTDC")
    expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(["CERTDC"])
    expect(result.requested_data_streams).to eq(["CERTDC"])
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure. Ce
  # que la liste projette est éprouvé sur Subscription::List ; ici, qu'elle est lue et servie.
  # Sans choix, un rattachement non restreint ne filtre rien : l'amont sert toute l'organisation.
  it "offers an unrestricted local administrator the data streams its organisation reads through the portal" do
    membership = create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
    expect(Portail::HubAPI::Subscriptions).to receive(:list)
      .with(siret: "22770001000019", insee_code: "77372").and_return(upstream_subscriptions("CERTDC", "AEC"))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(%w[AEC CERTDC])
    expect(result.requested_data_streams).to eq([])
  end

  # Le flux choisi remplace le périmètre, jamais ne l'élargit.
  it "narrows the filter to the chosen data streams when they are all among the offered ones" do
    membership = create(:membership)
    create(:process_access, membership: membership, process_code: "CERTDC")
    create(:process_access, membership: membership, process_code: "AEC")

    result = described_class.call(membership: membership, criteria: criteria(flux: ["AEC", "CERTDC"]))

    expect(result).to be_success
    expect(result.requested_data_streams).to eq(["AEC", "CERTDC"])
  end

  # Un administrateur non restreint aussi : l'amont accepterait n'importe quel code, le portail
  # borne à ce qu'il a lui-même proposé.
  it "fails as an invalid request, logged, when a chosen data stream is outside the offered ones" do
    membership = create(:membership, :local_administrator)
    expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(upstream_subscriptions("CERTDC"))

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, criteria: criteria(flux: ["CERTDC", "DEMO_AUTRE"]))
    end

    expect(result).to be_failure
    expect(result.error).to eq(:invalid_request)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: 'Flux hors des flux sélectionnables — ["DEMO_AUTRE"]'
    ))
  end

  # Les abonnements d'une structure bougent rarement : un appel par structure et par dix minutes.
  it "keeps the organisation data streams for ten minutes, per organisation" do
    memory = ActiveSupport::Cache::MemoryStore.new
    expect(Rails).to receive(:cache).at_least(:once).and_return(memory)
    membership = create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
    other = create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "13002526500013", insee_code: "75056"))
    expect(Portail::HubAPI::Subscriptions).to receive(:list)
      .with(siret: "22770001000019", insee_code: "77372").once.and_return(upstream_subscriptions("CERTDC"))
    expect(Portail::HubAPI::Subscriptions).to receive(:list)
      .with(siret: "13002526500013", insee_code: "75056").once.and_return(upstream_subscriptions("AEC"))

    expect(described_class.call(membership: membership, criteria: criteria).selectable_data_streams).to eq(["CERTDC"])
    expect(described_class.call(membership: membership, criteria: criteria).selectable_data_streams).to eq(["CERTDC"])
    expect(described_class.call(membership: other, criteria: criteria).selectable_data_streams).to eq(["AEC"])

    travel 11.minutes do
      expect(Portail::HubAPI::Subscriptions).to receive(:list)
        .with(siret: "22770001000019", insee_code: "77372").once.and_return(upstream_subscriptions("CERTDC"))

      expect(described_class.call(membership: membership, criteria: criteria).selectable_data_streams).to eq(["CERTDC"])
    end
  end

  # Un périmètre vide ne part jamais en aval : une liste de codes vide y vaut « aucun filtre ».
  it "fails without calling the upstream when the membership has no access" do
    expect(Portail::HubAPI::Subscriptions).not_to receive(:list)

    result = described_class.call(membership: create(:membership), criteria: criteria)

    expect(result).to be_failure
    expect(result.error).to eq(:no_habilitation)
  end

  # Même amont que la liste : sans lui, pas de page.
  it "fails as unavailable, logged, when the upstream is failing" do
    membership = create(:membership, :local_administrator)
    expect(Portail::HubAPI::Subscriptions).to receive(:list).and_raise(Portail::HubAPI::Unavailable)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, criteria: criteria)
    end

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Flux indisponibles"))
  end
end
