# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Deliveries::Show::FindDelivery do
  let(:membership) do
    create(:membership,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure.
  it "fetches the delivery within the organisation of the membership" do
    delivery = build(:portail_delivery)
    expect(Portail::HubAPI::Deliveries).to receive(:find)
      .with(id: "an-id", siret: "22770001000019", insee_code: "77372")
      .and_return(delivery)

    result = described_class.call(membership: membership, id: "an-id")

    expect(result).to be_success
    expect(result.delivery).to eq(delivery)
  end

  # L'identifiant en champ, pas dans le message : il se filtre au journal, et `reason` sépare
  # l'UUID que l'amont ne connaît pas du bruit des identifiants malformés.
  it "fails as not found, logged under a searchable identifier, when the upstream serves none" do
    expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, id: "94b1b09d-b47f-4480-9b48-93b8b36108f2")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Démarche introuvable en amont",
      payload_includes: {id: "94b1b09d-b47f-4480-9b48-93b8b36108f2", reason: :unknown}
    ))
  end

  # La panne est signalée par la couche de traduction : ici, seulement le journal et l'échec.
  it "fails as unavailable, logged, when the upstream is failing" do
    expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, id: "an-id")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(level: :error, message_includes: "Démarches indisponibles"))
  end

  # L'identifiant vient de l'URL : sans bouchon de la couche de traduction, c'est le refus réel
  # de la gem qui doit arriver ici.
  it "treats a refused argument as not found, logged under its own reason" do
    use_hub_api_fake_client

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, id: " ")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Démarche introuvable en amont", payload_includes: {id: " ", reason: :invalid_id}
    ))
  end
end
