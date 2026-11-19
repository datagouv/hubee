# frozen_string_literal: true

# Simule un retour ProConnect en bouchonnant Portail::ProConnect::Client, seul point de
# contact avec le fournisseur. Frontière : les request specs valident l'orchestration et
# l'UX ; le protocole et la crypto sont éprouvés dans spec/lib/portail/pro_connect/.
module ProConnectTestHelper
  # Jamais le SIRET des seeds (13002526500013) : collision connue avec des specs de l'API.
  TEST_SIRET = "99999999911111"

  # Seconde moitié de l'identité de l'organisation, que la gem nomme `code_insee`.
  TEST_INSEE_CODE = "00001"

  STATE = "test-state"
  NONCE = "test-nonce"

  def mock_proconnect(sub:, email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin",
    amr: ["mfa"], acr: "eidas1", siret: TEST_SIRET, organization_label: "Mairie de Test",
    idp_id: nil, sid: "sid-#{SecureRandom.hex(4)}")
    mock_proconnect_transport(email:, first_name:, last_name:, siret:, organization_label:, idp_id:)

    # expect (pas allow) : le callback déclenche réellement cet appel, une fois. Un `sid` neuf par
    # défaut : chaque connexion simulée ouvre sa propre session ProConnect.
    expect(Portail::ProConnect::TokenVerifier).to receive(:call).and_return(sub:, amr:, acr:, sid:)
  end

  # Le transport aboutit, la vérification reste au spec : pour éprouver un refus ou une
  # panne de TokenVerifier. `allow` : un expect nu exige « exactement une fois », or le
  # nombre d'échanges varie selon l'exemple — qui veut compter pose son propre expect.
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

  # Une vraie requête de départ : elle pose `state` et `nonce`, que le callback exige.
  def depart_for_proconnect
    allow(Portail::ProConnect::Client).to receive(:authorization).and_return(
      Portail::ProConnect::Client::Authorization.new(
        url: "https://proconnect.test/api/v2/authorize", state: STATE, nonce: NONCE
      )
    )
    post proconnect_authorization_path
  end

  # Le départ est refait à chaque fois, comme en réalité : le `state` est à usage unique.
  # Un spec qui veut un `state` invalide appelle `get` lui-même.
  def proconnect_callback(params = {})
    depart_for_proconnect
    get "/connexion/proconnect/retour", params: {code: "test-code", state: STATE}.merge(params)
  end

  # Le parcours complet d'une réauthentification, agent déjà connecté : départ, retour de
  # déconnexion, retour de connexion. Ce que ProConnect renvoie au dernier retour se simule avant,
  # par `mock_proconnect` ; un spec qui veut un retour en erreur passe `params:`. `expect` : le
  # parcours fait toujours ces deux appels, une fois chacun.
  def reauthenticate(purpose:, return_to: "/", params: {})
    expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
      .and_return("https://proconnect.test/api/v2/session/end")
    expect(Portail::ProConnect::Client).to receive(:authorization).and_return(
      Portail::ProConnect::Client::Authorization.new(
        url: "https://proconnect.test/api/v2/authorize", state: STATE, nonce: NONCE
      )
    )
    post reauthentication_path, params: {purpose:, return_to:}
    get reauthentication_resume_path
    get "/connexion/proconnect/retour", params: {code: "test-code", state: STATE}.merge(params)
  end

  # La preuve d'une réauthentification posée directement sur la session ouverte, pour les specs qui
  # n'éprouvent pas le parcours lui-même.
  def grant_reauthentication(purpose:)
    Portail::Access::Reauthentication.record!(ProviderSession.granted.sole, purpose:,
      id_token: "reauthenticated-id-token", acr: "eidas1-mfa", amr: ["mfa"])
  end

  # Garantit le rattachement correspondant au SIRET simulé : un spec qui veut un refus
  # construit sa situation lui-même.
  def sign_in_via_proconnect(agent:, amr: ["mfa"], acr: "eidas1", siret: TEST_SIRET, idp_id: nil)
    link = OrganizationLink.find_or_create_by!(siret: siret, insee_code: TEST_INSEE_CODE)
    Membership.find_or_create_by!(agent: agent, organization_link: link)
    mock_proconnect(sub: agent.provider_sub, email: agent.email, amr:, acr:, siret:, idp_id:)
    proconnect_callback
  end
end

RSpec.configure do |config|
  config.include ProConnectTestHelper, type: :request
end
