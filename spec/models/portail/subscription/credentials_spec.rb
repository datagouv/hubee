# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Subscription::Credentials do
  # Tiré au hasard : aucune chaîne qui ressemble à un secret dans le dépôt (GitGuardian), et une
  # spec de non-fuite qui ne peut pas passer sur une valeur connue.
  let(:secret_value) { SecureRandom.hex(16) }
  let(:secret) { HubApiV1::Secret.new(secret_value) }

  it "keeps the secret wrapped and filtered out of its inspect" do
    credentials = described_class.new(client_id: "SI-1", client_secret: secret)

    expect(credentials.client_secret.reveal).to eq(secret_value)
    expect(credentials.inspect).to include("client_secret=[FILTERED]")
    expect(credentials.inspect).not_to include(secret_value)
  end

  # Une chaîne nue serait en clair dans le premier inspect venu, et le message ne la cite pas.
  it "refuses a secret that is not wrapped" do
    expect { described_class.new(client_id: "SI-1", client_secret: secret_value) }
      .to raise_error(TypeError, "client_secret must be a HubApiV1::Secret")
  end
end
