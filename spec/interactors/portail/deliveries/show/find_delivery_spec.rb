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

  # L'identifiant vient de l'URL et finit au journal : des retours à la ligne y forgeraient de
  # fausses lignes. Une inexistence n'est pas un incident, Sentry n'est pas réveillé.
  it "fails as not found, logged under an inspected identifier, when the upstream serves none" do
    expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::NotFound)
    expect(Sentry).not_to receive(:capture_exception)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, id: "evil\nforged")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: 'Démarche introuvable en amont : "evil\nforged"'
    ))
  end

  # Une panne est un incident : quelqu'un est réveillé.
  it "fails as unavailable and reports the outage when the upstream is failing" do
    expect(Portail::HubAPI::Deliveries).to receive(:find).and_raise(Portail::HubAPI::Unavailable)
    expect(Sentry).to receive(:capture_exception).with(Portail::HubAPI::Unavailable)

    result = described_class.call(membership: membership, id: "an-id")

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
  end

  # L'identifiant vient de l'URL : un robot qui balaie `/demarches/%20` noierait Sentry. Sans
  # bouchon de la couche de traduction : c'est le refus réel de la gem qui doit arriver ici.
  it "treats a refused argument as not found, logged and without alert" do
    use_hub_api_fake_client
    expect(Sentry).not_to receive(:capture_exception)

    result = nil
    events = capture_semantic_logger_events do
      result = described_class.call(membership: membership, id: " ")
    end

    expect(result).to be_failure
    expect(result.error).to eq(:not_found)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: 'Démarche introuvable en amont : " "'
    ))
  end
end
