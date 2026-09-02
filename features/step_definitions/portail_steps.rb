# frozen_string_literal: true

# Hors de la plage des factories et des seeds, comme dans les request specs.
E2E_SIRET = "99999999911111"

Étantdonné("un agent rattaché à une organisation") do
  @agent = create(:agent, email: "agent@example.gouv.fr", first_name: "Alex", last_name: "Martin")
  link = OrganizationLink.find_or_create_by!(siret: E2E_SIRET, insee_code: "00001")
  create(:membership, agent: @agent, organization_link: link)
end

# ProConnect simulé : l'URL d'autorisation boucle sur notre propre callback avec le state
# attendu — le navigateur joue toute la chaîne de redirections, sans réseau.
Étantdonné("ProConnect est prêt à l'authentifier") do
  allow(Portail::ProConnect::Client).to receive(:authorization).and_return(
    Portail::ProConnect::Client::Authorization.new(
      url: "/connexion/proconnect/retour?code=test-code&state=test-state",
      state: "test-state", nonce: "test-nonce"
    )
  )
  allow(Portail::ProConnect::Client).to receive(:exchange).and_return(
    Portail::ProConnect::Client::Tokens.new(
      id_token: "test-id-token",
      info: Portail::ProConnect::Client::Info.new(
        email: @agent.email, first_name: @agent.first_name, last_name: @agent.last_name
      ),
      siret: E2E_SIRET, idp_id: nil, organization_label: "Mairie de Test"
    )
  )
  allow(Portail::ProConnect::TokenVerifier).to receive(:call)
    .and_return(sub: "sub-e2e", amr: ["mfa"], acr: "eidas1")
  # La déconnexion revient chez nous plutôt que de partir vers un ProConnect inexistant.
  allow(Portail::ProConnect::Client).to receive(:logout_url).and_return("/")
end

Étantdonné("il s'est connecté") do
  visit "/"
  click_button "S'identifier avec ProConnect"
end

Quand("il se rend sur l'accueil") do
  visit "/"
end

Quand("il clique sur {string}") do |label|
  click_button label
end

Alors("il est connecté au portail") do
  expect(page).to have_text("Connecté en tant que Alex (agent@example.gouv.fr)")
end

Alors("il est revenu déconnecté à l'accueil") do
  expect(page).to have_button("S'identifier avec ProConnect")
  expect(page).to have_no_text("Connecté en tant que")
end

# Le markup du bouton et son lien d'information sont imposés par la charte ProConnect.
Alors("la page propose le bouton officiel ProConnect") do
  expect(page).to have_button("S'identifier avec ProConnect")
  expect(page).to have_css("button.proconnect-button")
  expect(page).to have_link("Qu'est-ce que ProConnect ?", href: "https://www.proconnect.gouv.fr/")
  expect(page).to have_no_button("Se déconnecter")
end

# Migré du system spec portail_home_dsfr_layout : mêmes garanties, ici en Gherkin.
Alors("la page porte le socle DSFR complet") do
  # Liens d'évitement (RGAA)
  expect(page).to have_link("Contenu", href: "#content")

  # En-tête / landmark banner
  expect(page).to have_css("header.fr-header[role='banner']")
  expect(page).to have_content("HubEE")
  expect(page).to have_content("Plateforme d'échange sécurisé de fichiers entre administrations")

  # Navigation principale
  expect(page).to have_link("Accueil", href: "/")

  # Landmark main + contenu de la page d'accueil
  expect(page).to have_css("main#content[role='main']")
  expect(page).to have_content("Portail HubEE")

  # Pied de page / landmark contentinfo + liens légaux obligatoires DSFR
  expect(page).to have_css("footer.fr-footer[role='contentinfo']#footer")
  expect(page).to have_link("Mentions légales")
  expect(page).to have_link("Données personnelles")

  # Hotwire câblé (importmap rendu dans la mise en page)
  expect(page).to have_css("script[type='importmap']", visible: :all)
end

# --- Démarches ------------------------------------------------------------------------------
#
# L'API amont est jouée par le client bouchonné de la gem (features/support/world.rb) : aucune
# de nos classes n'est stubbée, toute la chaîne est traversée dans un vrai navigateur.

Étantdonné("il est habilité sur le flux {string}") do |code|
  create(:process_access, membership: Membership.find_by!(agent: @agent), process_code: code)
end

Étantdonné("l'API amont sert une démarche pour son organisation") do
  HubApiV1.client.add_case(build_v2_delivery(state: :transmitted, recipient: e2e_recipient))
end

Étantdonné("l'API amont sert aussi une démarche sur un flux non habilité") do
  @unauthorised_id = "0a11c2f4-0000-4000-8000-000000000042"
  HubApiV1.client.add_case(
    build_v2_delivery(
      id: @unauthorised_id, number: "DGS-AEC-0000000000002-01", state: :transmitted,
      data_stream: HubApiV1::V2::DataStream.new(code: "AEC"), recipient: e2e_recipient
    )
  )
end

Étantdonné("l'API amont sert aussi une démarche traitée pour son organisation") do
  HubApiV1.client.add_case(
    build_v2_delivery(
      id: "0a11c2f4-0000-4000-8000-000000000043", number: "DGS-CERTDC-0000000000003-01",
      state: :done, recipient: e2e_recipient
    )
  )
end

Quand("il filtre sur l'état {string}") do |label|
  within("nav.fr-sidemenu") { click_link label }
end

Quand("il ouvre la démarche {string}") do |number|
  click_link number
end

Quand("il ouvre directement cette démarche") do
  visit "/demarches/#{@unauthorised_id}"
end

Alors("il voit la démarche {string} dans la liste") do |number|
  expect(page).to have_css("table caption", text: "Transmise")
  expect(page).to have_link(number)
end

Alors("il voit le détail de la démarche, demandeur compris") do
  expect(page).to have_css("h1", text: "Démarche DGS-CERTDC-0000000000001-01")
  expect(page).to have_text("CERTDC")
  # Le demandeur est absent de la liste, présent au détail : ce qui distingue les deux écrans.
  expect(page).to have_text("George DUBOIS")
end

Alors("il voit l'inventaire des pièces et l'historique") do
  expect(page).to have_css("h2", text: "Pièces du dépôt")
  expect(page).to have_text("certificat.pdf")
  expect(page).to have_css("h2", text: "Historique")
  expect(page).to have_text("George DUBOIS a modifié le statut : Transmise → Reçue")
end

Alors("la liste est celle de l'état {string}") do |label|
  expect(page).to have_css("table caption", text: label)
  expect(page).to have_css("nav.fr-sidemenu a[aria-current='page']", text: label)
end

Alors("il obtient une page introuvable, sans que le dossier lui soit montré") do
  expect(page).to have_text("Page introuvable")
  expect(page).to have_no_text("DGS-AEC-0000000000002-01")
end
