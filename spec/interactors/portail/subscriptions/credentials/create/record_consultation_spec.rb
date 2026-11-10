# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::Credentials::Create::RecordConsultation do
  def credentials = Portail::Subscription::Credentials.new(client_id: "client-42", client_secret: "s3cr3t")

  # L'agent et son organisation sont recopiés dans la trace : elle doit encore dire qui a consulté,
  # et pour quelle organisation, une fois l'agent ou son rattachement supprimé.
  it "records who revealed which subscription for which organization, without the secret" do
    membership = create(:membership, :local_administrator)
    subscription = build(:portail_subscription, id: "sub-1", data_stream_code: "CERTDC", access_mode: "api")

    result = described_class.call(membership: membership, subscription: subscription, credentials: credentials)

    expect(result).to be_success
    expect(Event.sole).to have_attributes(
      eventable: membership,
      event_type: "subscription.credentials_revealed",
      metadata: {
        "subscription_id" => "sub-1",
        "data_stream_code" => "CERTDC",
        "agent_id" => membership.agent_id,
        "email" => membership.agent.email,
        "siret" => membership.organization_link.siret,
        "insee_code" => membership.organization_link.insee_code
      }
    )
    expect(Event.sole.metadata.to_json).not_to include("s3cr3t")
  end

  # Pas de trace, pas d'affichage : le contrôleur ne montre les identifiants qu'en succès.
  it "fails as unavailable and drops the credentials when the trace cannot be written" do
    membership = create(:membership, :local_administrator)
    expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    result = described_class.call(membership: membership,
      subscription: build(:portail_subscription, access_mode: "api"), credentials: credentials)

    expect(result).to be_failure
    expect(result.error).to eq(:unavailable)
    expect(result.credentials).to be_nil
  end
end
