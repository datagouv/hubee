# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Create::AdoptIdToken do
  # Les niveaux restent ceux de la session tant que la réauthentification n'a pas abouti : un retour
  # sans second facteur ferait sinon éjecter l'administrateur local à la requête suivante.
  # Le `sid` suit le jeton : la réauthentification suivante doit en présenter un autre que celui de
  # la session ProConnect ouverte ici, même si celle-ci est refusée ensuite.
  it "replaces the session's ProConnect token and session id, not its levels" do
    provider_session = create(:provider_session, provider_id_token: "old-token", provider_sid: "sid-old",
      acr: "eidas1-mfa", amr: ["mfa"])

    described_class.call(provider_session:, id_token: "new-token", claims: {acr: "eidas1", amr: ["pwd"], sid: "sid-new"})

    expect(provider_session.reload).to have_attributes(provider_id_token: "new-token", provider_sid: "sid-new",
      acr: "eidas1-mfa", amr: ["mfa"])
  end
end
