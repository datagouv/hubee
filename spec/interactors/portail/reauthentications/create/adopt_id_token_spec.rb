# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Create::AdoptIdToken do
  # Les niveaux restent ceux de la session tant que la réauthentification n'a pas abouti : un retour
  # sans second facteur ferait sinon éjecter l'administrateur local à la requête suivante.
  it "replaces the session's ProConnect token, not its levels" do
    provider_session = create(:provider_session, provider_id_token: "old-token", acr: "eidas1-mfa", amr: ["mfa"])

    described_class.call(provider_session:, id_token: "new-token", claims: {acr: "eidas1", amr: ["pwd"]})

    expect(provider_session.reload).to have_attributes(provider_id_token: "new-token", acr: "eidas1-mfa", amr: ["mfa"])
  end
end
