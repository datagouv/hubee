# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::CredentialConsultations::Create::RecordConsultation do
  let(:agent) { create(:agent, email: "admin@commune.fr") }
  let(:membership) do
    create(:membership, :local_administrator, agent: agent,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
  end
  let(:subscription) { build(:portail_subscription, membership: membership, access_mode: "api") }
  # Tiré au hasard : aucune chaîne qui ressemble à un secret dans le dépôt (GitGuardian), et une
  # spec de non-fuite qui ne peut pas passer sur une valeur connue.
  let(:secret_value) { SecureRandom.hex(16) }
  let(:credentials) do
    Portail::Subscription::Credentials.new(client_id: "SI-22770001000019-77372-CERTDC",
      client_secret: HubApiV1::Secret.new(secret_value))
  end

  def call = described_class.call(membership: membership, subscription: subscription,
    credentials: credentials, request_id: "req-42")

  # Recopiés : la trace doit encore dire qui a consulté, et pour quelle organisation, une fois
  # l'agent ou son rattachement supprimé.
  it "records who viewed which subscription, without the credentials" do
    expect { call }.to change(Event, :count).by(1)

    event = Event.last
    expect(event).to have_attributes(eventable: membership, event_type: "subscription_credentials.consulted")
    expect(event.metadata).to eq(
      "agent_id" => agent.id, "email" => "admin@commune.fr", "siret" => "22770001000019",
      "insee_code" => "77372", "subscription_id" => subscription.id, "data_stream_code" => "CERTDC",
      "request_id" => "req-42"
    )
    expect(event.metadata.to_json).not_to include("SI-22770001000019-77372-CERTDC")
    expect(event.metadata.to_json).not_to include(secret_value)
  end

  it "logs the consultation without personal data" do
    events = capture_semantic_logger_events { call }

    expect(events).to include(be_a_semantic_logger_event(
      level: :info, message: "Identifiants d'abonnement consultés",
      payload: {subscription_id: subscription.id, membership_id: membership.id, agent_id: agent.id}
    ))
  end
end
