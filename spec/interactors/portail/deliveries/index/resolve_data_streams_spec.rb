# frozen_string_literal: true

require "rails_helper"

# Les flux proposés au filtre et le filtre envoyé à l'amont : ceux que l'organisation reçoit par le
# portail, bornés par le périmètre du rattachement quand il en a un. La seconde branche disparaîtra
# avec les habilitations des administrateurs locaux.
RSpec.describe Portail::Deliveries::Index::ResolveDataStreams do
  def criteria(**params) = Portail::Delivery::Criteria.from_params(params)

  # Chaque flux nommé « <code> nommé », pour reconnaître d'où vient un nom. Reçus par le portail,
  # sauf ceux nommés dans `api:`.
  def upstream_subscriptions(*codes, api: [])
    build(:portail_subscription_list, subscriptions: codes.map.with_index do |code, index|
      build(:portail_subscription, id: "sub-#{index}", data_stream_code: code, data_stream_name: "#{code} nommé",
        access_mode: api.include?(code) ? "api" : "portal")
    end)
  end

  # Ses flux viennent de ses habilitations ; les abonnements ne servent qu'à les nommer, tous,
  # même ceux qu'il n'a pas : un nom n'ouvre rien.
  it "offers a habilitated member its data streams, sorted, named from the organisation subscriptions, and filters on them" do
    membership = create(:membership,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
    create(:data_stream_access, membership: membership, data_stream_code: "CERTDC")
    create(:data_stream_access, membership: membership, data_stream_code: "AEC")
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch)
      .with(siret: "22770001000019", insee_code: "77372")
      .and_return(upstream_subscriptions("CERTDC", "AEC", "DEMO"))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(%w[AEC CERTDC])
    expect(result.data_stream_names)
      .to eq({"CERTDC" => "CERTDC nommé", "AEC" => "AEC nommé", "DEMO" => "DEMO nommé"})
    expect(result.requested_data_streams).to eq(%w[AEC CERTDC])
  end

  # Le système client de l'organisation traite ce flux : l'habilitation n'y change rien. Nommé
  # quand même, un nom n'ouvre rien.
  it "offers a habilitated member only the data streams its organisation receives through the portal, and filters on them" do
    membership = create(:membership)
    create(:data_stream_access, membership: membership, data_stream_code: "CERTDC")
    create(:data_stream_access, membership: membership, data_stream_code: "DEMO_API")
    create(:data_stream_access, membership: membership, data_stream_code: "DEMO_NON_ABONNE")
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch)
      .and_return(upstream_subscriptions("CERTDC", "DEMO_API", api: ["DEMO_API"]))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(["CERTDC"])
    expect(result.data_stream_names).to eq({"CERTDC" => "CERTDC nommé", "DEMO_API" => "DEMO_API nommé"})
    expect(result.requested_data_streams).to eq(["CERTDC"])
  end

  # Un filtre vide vaudrait toute l'organisation en aval : rien à demander, la page le dit.
  it "fails as without habilitation when none of the member data streams is received through the portal" do
    membership = create(:membership)
    create(:data_stream_access, membership: membership, data_stream_code: "DEMO_API")
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch)
      .and_return(upstream_subscriptions("DEMO_API", api: ["DEMO_API"]))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_failure
    expect(result.error).to eq(:no_habilitation)
  end

  it "offers a local administrator with named habilitations those alone" do
    membership = create(:membership, :local_administrator)
    create(:data_stream_access, membership: membership, data_stream_code: "CERTDC")
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(upstream_subscriptions("CERTDC", "AEC"))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(["CERTDC"])
    expect(result.requested_data_streams).to eq(["CERTDC"])
  end

  # Sans les abonnements, le mode d'accès de ses flux est inconnu : rien à proposer, pas de page.
  # La panne est déjà journalisée par la frontière, qui rend nil.
  it "fails as unavailable when the subscriptions could not be read for a habilitated member" do
    membership = create(:membership)
    create(:data_stream_access, membership: membership, data_stream_code: "CERTDC")
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(nil)

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure. Ce
  # que la liste projette est éprouvé sur Subscription::List ; ici, qu'elle est lue et servie.
  # Sans choix, un rattachement non restreint filtre aussi, sur ces flux-là : sans filtre, l'amont
  # servirait toute l'organisation, flux reçus par l'API compris.
  it "offers an unrestricted local administrator the data streams its organisation reads through the portal, and filters on them" do
    membership = create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch)
      .with(siret: "22770001000019", insee_code: "77372")
      .and_return(upstream_subscriptions("CERTDC", "AEC", "DEMO_API", api: ["DEMO_API"]))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_success
    expect(result.selectable_data_streams).to eq(%w[AEC CERTDC])
    expect(result.data_stream_names)
      .to eq({"CERTDC" => "CERTDC nommé", "AEC" => "AEC nommé", "DEMO_API" => "DEMO_API nommé"})
    expect(result.requested_data_streams).to eq(%w[AEC CERTDC])
  end

  it "fails as without habilitation when the organisation of an unrestricted local administrator receives nothing through the portal" do
    membership = create(:membership, :local_administrator)
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch)
      .and_return(upstream_subscriptions("DEMO_API", api: ["DEMO_API"]))

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_failure
    expect(result.error).to eq(:no_habilitation)
  end

  # Le flux choisi remplace le périmètre, jamais ne l'élargit.
  it "narrows the filter to the chosen data streams when they are all among the offered ones" do
    membership = create(:membership)
    create(:data_stream_access, membership: membership, data_stream_code: "CERTDC")
    create(:data_stream_access, membership: membership, data_stream_code: "AEC")
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(upstream_subscriptions("CERTDC", "AEC"))

    result = described_class.call(membership: membership, criteria: criteria(flux: ["AEC", "CERTDC"]))

    expect(result).to be_success
    expect(result.requested_data_streams).to eq(["AEC", "CERTDC"])
  end

  # Un administrateur non restreint aussi : l'amont accepterait n'importe quel code, le portail
  # borne à ce qu'il a lui-même proposé.
  it "fails as an invalid request, logged, when a chosen data stream is outside the offered ones" do
    membership = create(:membership, :local_administrator)
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(upstream_subscriptions("CERTDC"))

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

  # Sans habilitation, la réponse se sait sans l'amont : ni appel, ni panne qui la masquerait.
  it "fails as without habilitation without reading the subscriptions for a member without habilitation" do
    expect(Portail::HubAPI::Subscriptions).not_to receive(:fetch)

    result = described_class.call(membership: create(:membership), criteria: criteria)

    expect(result).to be_failure
    expect(result.error).to eq(:no_habilitation)
  end

  # Sans abonnements, un rattachement non restreint n'a rien à proposer : pas de page.
  it "fails as unavailable when the subscriptions could not be read for an unrestricted local administrator" do
    membership = create(:membership, :local_administrator)
    expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(nil)

    result = described_class.call(membership: membership, criteria: criteria)

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
  end
end
