# frozen_string_literal: true

# Simule un retour ProConnect. Remplace le mode test d'OmniAuth : on bouchonne
# Portail::ProConnect::Client, seul point de contact avec le fournisseur.
#
# La frontière est la même qu'avant : les request specs valident l'orchestration et l'UX,
# pas le protocole ni la cryptographie — ceux-là sont éprouvés en propre dans
# spec/lib/portail/pro_connect/{client,token_verifier}_spec.rb.
module ProConnectTestHelper
  # Jamais le SIRET des seeds (13002526500013) : collision connue avec des specs de l'API.
  # Hors de la plage générée par la factory organization_link, pour éviter tout doublon.
  TEST_SIRET = "99999999911111"

  STATE = "test-state"
  NONCE = "test-nonce"

  def mock_proconnect(sub:, email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin",
    amr: ["mfa"], acr: "eidas1", siret: TEST_SIRET, organization_label: "Mairie de Test",
    idp_id: nil)
    mock_proconnect_transport(email:, first_name:, last_name:, siret:, organization_label:, idp_id:)

    # expect (pas allow) : le callback DÉCLENCHE réellement cet appel — la règle
    # « expect jamais allow » (rspec-conventions) s'applique, l'appel a bien lieu.
    expect(Portail::ProConnect::TokenVerifier).to receive(:call).and_return(sub:, amr:, acr:)
  end

  # Le transport aboutit, mais rien n'est dit de la vérification : pour les specs qui
  # bouchonnent TokenVerifier eux-mêmes, en refus ou en panne.
  def mock_proconnect_transport(email: "agent@example.gouv.fr", first_name: "Alex",
    last_name: "Martin", siret: TEST_SIRET, organization_label: "Mairie de Test", idp_id: nil)
    allow(Portail::ProConnect::Client).to receive(:exchange).and_return(
      Portail::ProConnect::Client::Tokens.new(
        id_token: "test-id-token",
        info: Portail::ProConnect::Client::Info.new(email:, first_name:, last_name:),
        siret:, idp_id:, organization_label:
      )
    )
  end

  # Le départ pose `state` et `nonce` en session, et le callback les exige. Le parcours de
  # test passe donc par une vraie requête de départ — au passage, il éprouve la
  # vérification du `state`, que le mode test d'OmniAuth court-circuitait.
  def depart_for_proconnect
    allow(Portail::ProConnect::Client).to receive(:authorization).and_return(
      Portail::ProConnect::Client::Authorization.new(
        url: "https://proconnect.test/api/v2/authorize", state: STATE, nonce: NONCE
      )
    )
    post proconnect_authorization_path
  end

  # Remplace `get "/auth/proconnect/callback"`. Le départ est refait à chaque fois, comme
  # dans la réalité : le `state` est à usage unique, on n'arrive jamais au callback sans
  # être parti. Une spec qui veut éprouver un `state` invalide appelle `get` elle-même.
  def proconnect_callback(params = {})
    depart_for_proconnect
    get "/auth/proconnect/callback", params: {code: "test-code", state: STATE}.merge(params)
  end

  # Se connecter suppose d'avoir le droit d'entrer : le helper garantit le rattachement
  # correspondant au SIRET simulé. Un spec qui veut éprouver un refus construit sa
  # situation lui-même plutôt que de passer par ici.
  def sign_in_via_proconnect(agent:, amr: ["mfa"], acr: "eidas1", siret: TEST_SIRET, idp_id: nil)
    link = OrganizationLink.find_or_create_by!(siret: siret)
    Membership.find_or_create_by!(agent: agent, organization_link: link)
    mock_proconnect(sub: agent.provider_sub, email: agent.email, amr:, acr:, siret:, idp_id:)
    proconnect_callback
  end
end

RSpec.configure do |config|
  config.include ProConnectTestHelper, type: :request
end
