# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::CredentialConsultations::Create::FetchCredentials do
  let(:membership) do
    create(:membership, :local_administrator,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end
  let(:subscription) { build(:portail_subscription, membership: membership, access_mode: "api") }

  def call = described_class.call(membership: membership, subscription: subscription)

  # Le couple doit venir du rattachement : pris ailleurs, il ouvrirait une autre structure.
  it "puts the credentials in the context, asked within the organisation of the membership" do
    credentials = Portail::Subscription::Credentials.new(client_id: "SI-1", client_secret: HubApiV1::Secret.new(SecureRandom.hex(16)))
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials)
      .with(id: subscription.id, siret: "22770001000019", insee_code: "77372")
      .and_return(credentials)

    result = call

    expect(result).to be_success
    expect(result.credentials).to eq(credentials)
  end

  # L'abonnement vient d'être lu : un introuvable sur la route des identifiants est une anomalie
  # (route absente d'un environnement, abonnement supprimé entre-temps), pas une réponse à l'agent.
  it "fails as unavailable, logged as a warning, when the upstream no longer finds the subscription" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::NotFound)

    result = nil
    events = capture_semantic_logger_events { result = call }

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Identifiants d'abonnement introuvables en amont",
      payload_includes: {subscription_id: subscription.id}
    ))
  end

  it "fails as unavailable, logged as a warning, on an id the upstream refuses" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::InvalidRequest)

    result = nil
    events = capture_semantic_logger_events { result = call }

    expect(result.error).to eq(:unavailable)
    expect(events).to include(be_a_semantic_logger_event(
      level: :warn, message: "Identifiants d'abonnement introuvables en amont"
    ))
  end

  # Un cas pour l'équipe HubEE : journalisé, pour qu'elle retrouve l'abonnement concerné.
  it "fails as refused, logged, when the upstream refuses to serve the credentials" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::CredentialsRefused)

    result = nil
    events = capture_semantic_logger_events { result = call }

    expect(result).to be_failure
    expect(result.error).to eq(:refused)
    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Identifiants d'abonnement refusés en amont",
      payload_includes: {subscription_id: subscription.id}
    ))
  end

  it "fails as unavailable when the upstream is failing" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    result = call

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
  end
end
