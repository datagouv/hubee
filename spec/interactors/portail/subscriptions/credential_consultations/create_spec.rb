# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscriptions::CredentialConsultations::Create do
  let(:membership) { create(:membership, :local_administrator) }
  let(:subscription) { build(:portail_subscription, membership: membership, access_mode: "api") }
  let(:credentials) do
    Portail::Subscription::Credentials.new(client_id: "SI-1", client_secret: HubApiV1::Secret.new(SecureRandom.hex(16)))
  end

  def call = described_class.call(membership: membership, subscription: subscription, request_id: "req-42")

  it "hands back the credentials, the consultation recorded" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(credentials)

    result = nil
    expect { result = call }.to change(Event, :count).by(1)

    expect(result).to be_success
    expect(result.credentials).to eq(credentials)
  end

  # Une trace par consultation servie : rien n'a été montré, rien n'est tracé.
  it "records no event when the credentials cannot be read" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::CredentialsRefused)

    result = nil
    expect { result = call }.not_to change(Event, :count)

    expect(result.error).to eq(:refused)
  end

  # Pas de trace, pas d'affichage : l'erreur remonte au lieu de rendre les identifiants.
  it "lets a failed event write raise, so nothing is shown" do
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(credentials)
    expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    expect { call }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
