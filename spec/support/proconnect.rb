# frozen_string_literal: true

# Simule un retour ProConnect via le mode test d'OmniAuth. La vérification
# cryptographique (TokenVerifier) est stubbée ici — elle est testée en propre
# dans spec/lib/portail/pro_connect/token_verifier_spec.rb (frontière : les request
# specs valident l'orchestration/UX, pas la crypto).
module ProConnectTestHelper
  # Jamais le SIRET des seeds (13002526500013) : collision connue avec des specs de l'API.
  # Hors de la plage générée par la factory organization_link, pour éviter tout doublon.
  TEST_SIRET = "99999999911111"

  def mock_proconnect(sub:, email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin",
    amr: ["mfa"], acr: "eidas1", siret: TEST_SIRET, organization_label: "Mairie de Test",
    idp_id: nil)
    OmniAuth.config.mock_auth[:proconnect] = OmniAuth::AuthHash.new(
      provider: "proconnect",
      uid: sub,
      info: {email:, first_name:, last_name:},
      credentials: {id_token: "test-id-token"},
      extra: {nonce: "test-nonce",
              raw_info: {"siret" => siret, "organization_label" => organization_label,
                         "idp_id" => idp_id}}
    )
    # TokenVerifier renvoie l'identité vérifiée à partir de l'id_token.
    # expect (pas allow) : le callback DÉCLENCHE réellement cet appel une fois — la règle
    # « expect jamais allow » (rspec-conventions) s'applique, l'appel a bien lieu.
    expect(Portail::ProConnect::TokenVerifier).to receive(:call).and_return(sub:, amr:, acr:)
  end

  # Se connecter suppose d'avoir le droit d'entrer : le helper garantit le rattachement
  # correspondant au SIRET simulé. Un spec qui veut éprouver un refus construit sa
  # situation lui-même plutôt que de passer par ici.
  def sign_in_via_proconnect(agent:, amr: ["mfa"], acr: "eidas1", siret: TEST_SIRET, idp_id: nil)
    link = OrganizationLink.find_or_create_by!(siret: siret)
    Membership.find_or_create_by!(agent: agent, organization_link: link)
    mock_proconnect(sub: agent.provider_sub, email: agent.email, amr:, acr:, siret:, idp_id:)
    get "/auth/proconnect/callback"
  end
end

RSpec.configure do |config|
  config.include ProConnectTestHelper, type: :request
  config.before(:each, type: :request) { OmniAuth.config.test_mode = true }
  config.after(:each, type: :request) { OmniAuth.config.mock_auth[:proconnect] = nil }
end
