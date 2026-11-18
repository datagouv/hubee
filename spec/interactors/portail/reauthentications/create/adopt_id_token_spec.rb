# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Create::AdoptIdToken do
  it "replaces the session's ProConnect token and levels" do
    provider_session = create(:provider_session, provider_id_token: "old-token", acr: "eidas1", amr: ["pwd"])

    described_class.call(provider_session:, id_token: "new-token", claims: {acr: "eidas1-mfa", amr: ["mfa"]})

    expect(provider_session.reload).to have_attributes(provider_id_token: "new-token", acr: "eidas1-mfa", amr: ["mfa"])
  end
end
