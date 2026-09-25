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

# --- Télédossiers ------------------------------------------------------------------------------
#
# L'API amont est jouée par le client bouchonné de la gem (features/support/world.rb) : aucune
# de nos classes n'est stubbée, toute la chaîne est traversée dans un vrai navigateur.

Étantdonné("il est habilité sur le flux {string}") do |code|
  create(:data_stream_access, membership: Membership.find_by!(agent: @agent), data_stream_code: code)
end

# Le rôle ne tranche que la liste vide : les habilitations posées par le contexte sont retirées.
Étantdonné("il est administrateur local sans habilitation") do
  membership = Membership.find_by!(agent: @agent)
  membership.data_stream_accesses.destroy_all
  membership.update!(role: "local_administrator")
end

# Les quatre natures : lisible par le portail (deux flux), par l'API, non lisible, autre
# organisation du même SIRET. Seuls AEC et CERTDC doivent ressortir.
Étantdonné("l'API amont sert à sa structure des abonnements de toutes natures") do
  [
    {id: "sub-1", data_stream_code: "CERTDC", data_stream_name: "Certificat de décès électronique"},
    {id: "sub-2", data_stream_code: "AEC", data_stream_name: "Actes d'état civil"},
    {id: "sub-3", data_stream_code: "DEMO_API", data_stream_name: "Démonstration par l'API", access_mode: :api},
    {id: "sub-4", data_stream_code: "DEMO_INACTIF", data_stream_name: "Démonstration inactive", read_package: false},
    {id: "sub-5", data_stream_code: "DEMO_AUTRE", data_stream_name: "Démonstration d'une autre organisation",
     organization: build_v2_recipient(siret: E2E_SIRET, code_insee: "00002")}
  ].each { |subscription| HubApiV1.client.add_subscription(build_v2_subscription(organization: e2e_recipient, **subscription)) }
  HubApiV1.client.add_case(e2e_delivery("DGS-AEC-0000000000002-01",
    data_stream_code: "AEC"))
end

# L'intitulé voyage avec l'abonnement de la structure, c'est là que l'amont le sert.
Étantdonné("l'API amont nomme le flux {string} {string}") do |code, name|
  HubApiV1.client.add_subscription(build_v2_subscription(
    id: "sub-#{code}", organization: e2e_recipient,
    data_stream_code: code, data_stream_name: name
  ))
end

Étantdonné("l'API amont sert un télédossier pour son organisation") do
  HubApiV1.client.add_case(e2e_delivery("DGS-CERTDC-0000000000001-01"))
  # Déclarer le flux sert à deux choses : le nommer à l'écran, et borner ce qu'il autorise.
  HubApiV1.client.add_data_stream(build_v2_data_stream(code: "CERTDC", name: "Certificat de décès électronique"))
end

Étantdonné("l'API amont sert aussi un télédossier sur un flux non habilité") do
  @unauthorised_id = "0a11c2f4-0000-4000-8000-000000000042"
  HubApiV1.client.add_case(
    build_v2_delivery(
      id: @unauthorised_id, number: "DGS-AEC-0000000000002-01", state: :transmitted,
      data_stream_code: "AEC", recipient: e2e_recipient
    )
  )
end

Étantdonné("l'API amont sert aussi un télédossier traité pour son organisation") do
  HubApiV1.client.add_case(
    build_v2_delivery(
      id: "0a11c2f4-0000-4000-8000-000000000043", number: "DGS-CERTDC-0000000000003-01",
      state: :done, recipient: e2e_recipient
    )
  )
end

# L'identifiant dérive du numéro : distinct par télédossier, lisible dans un échec.
def e2e_delivery(number, **attributes)
  build_v2_delivery(
    id: format("0a11c2f4-0000-4000-8000-%012d", number[/\d{13}/].to_i), number: number,
    state: :transmitted, recipient: e2e_recipient, **attributes
  )
end

Étantdonné("l'API amont sert aussi un télédossier {string} sur le flux {string}") do |number, code|
  HubApiV1.client.add_case(e2e_delivery(number, data_stream_code: code))
end

# Un instant en heure de Paris : c'est ainsi que le portail borne la période.
Étantdonné("l'API amont sert aussi un télédossier {string} transmis le {string}") do |number, date|
  HubApiV1.client.add_case(e2e_delivery(number, transmitted_at: Time.zone.parse(date).noon))
end

Quand("il filtre sur l'état {string}") do |label|
  within("nav.fr-sidemenu") { click_link label }
end

# Le panneau des filtres est replié tant que rien ne filtre ; sans JavaScript, le bouton ne fait
# rien et le formulaire reste atteignable.
def open_filters
  toggle = first("button.fr-accordion__btn[aria-controls='delivery-filters']", minimum: 0)
  toggle.click if toggle && toggle["aria-expanded"] == "false"
end

# Dans un vrai navigateur, le DSFR masque la case native derrière son habillage : on coche par
# le libellé, et on la retrouve avec `visible: :all`.
Quand("il filtre sur le flux {string}") do |code|
  open_filters
  check code, allow_label_click: true
  click_button "Filtrer"
end

Quand("il filtre sur les flux {string}") do |codes|
  open_filters
  codes.split(", ").each { |code| check code, allow_label_click: true }
  click_button "Filtrer"
end

Quand("il filtre sur les télédossiers transmis jusqu'au {string}") do |date|
  open_filters
  fill_in "Jusqu'au", with: Date.parse(date)
  click_button "Filtrer"
end

Quand("il cherche le numéro {string}") do |number|
  open_filters
  fill_in "Numéro de télédossier", with: number
  click_button "Filtrer"
end

Quand("il trie par « {word} le »") do |column|
  within("table thead") { click_link "#{column} le" }
end

Quand("il ouvre le télédossier {string}") do |number|
  click_link number
end

Étantdonné("l'API amont sert aussi un télédossier en erreur d'intégration pour son organisation") do
  @unauthorised_id = "0a11c2f4-0000-4000-8000-000000000043"
  HubApiV1.client.add_case(
    build_v2_delivery(
      id: @unauthorised_id, number: "DGS-AEC-0000000000002-01", state: :integration_error,
      recipient: e2e_recipient
    )
  )
end

Alors("le menu des états ne propose pas {string}") do |label|
  expect(page).to have_css("nav.fr-sidemenu")
  expect(page).to have_no_css("nav.fr-sidemenu a", text: label)
end

Quand("il ouvre directement ce télédossier") do
  visit "/teledossiers/#{@unauthorised_id}"
end

# Les télédossiers servis par l'amont portent la pièce par défaut de la gem, dont le client
# bouchonné sert des octets déterministes de la taille annoncée.
def e2e_attachment(filename)
  build_v2_data_package.attachments.find { |attachment| attachment.filename == filename }
end

Quand("il télécharge la pièce {string}") do |filename|
  within("tr", text: filename) { click_link "Télécharger" }
end

Quand("il récupère directement la pièce {string} du télédossier {string}") do |filename, number|
  visit "/teledossiers/#{e2e_delivery(number).id}/pieces/#{e2e_attachment(filename).id}"
end

Quand("il récupère directement la pièce {string} de ce télédossier") do |filename|
  visit "/teledossiers/#{@unauthorised_id}/pieces/#{e2e_attachment(filename).id}"
end

Alors("il voit le télédossier {string} dans la liste") do |number|
  expect(page).to have_css("table caption", text: "Nouveau")
  expect(page).to have_link(number)
end

Alors("il voit le télédossier {string} sous la démarche {string}") do |number, label|
  expect(page.find("table tbody tr", text: number)).to have_css("td:nth-child(2)", text: label)
end

Alors("le filtre propose les flux {string}") do |codes|
  # `visible: :all` : le panneau est replié tant que rien ne filtre.
  within("fieldset#delivery-data-streams", visible: :all) do
    codes.split(", ").each { |code| expect(page).to have_unchecked_field(code, visible: :all) }
    expect(page).to have_css("input[type='checkbox']", count: codes.split(", ").size, visible: :all)
  end
end

Alors("il ne voit que le télédossier {string}") do |number|
  expect(page).to have_css("table tbody tr", count: 1)
  expect(page).to have_link(number)
end

Alors("il ne voit que les télédossiers {string}") do |numbers|
  expected = numbers.split(", ")
  expect(page).to have_css("table tbody tr", count: expected.size)
  expected.each { |number| expect(page).to have_link(number) }
end

Alors("aucun télédossier ne correspond à ses critères") do
  expect(page).to have_text("Aucun télédossier ne correspond à vos critères")
  expect(page).to have_no_css("table tbody tr")
end

Alors("les télédossiers sont listés dans l'ordre {string}") do |numbers|
  expect(page.all("table tbody tr td:first-child").map(&:text)).to eq(numbers.split(", "))
end

Alors("il voit le détail du télédossier, demandeur compris") do
  expect(page).to have_css("h1", text: "Télédossier DGS-CERTDC-0000000000001-01")
  expect(page).to have_text("CERTDC")
  # Le demandeur est absent de la liste, présent au détail : ce qui distingue les deux écrans.
  expect(page).to have_text("George DUBOIS")
end

Alors("il voit l'inventaire des pièces et l'historique") do
  expect(page).to have_css("h2", text: "Pièces du télédossier")
  expect(page).to have_text("certificat.pdf")
  expect(page).to have_css("h2", text: "Historique")
  expect(page).to have_text("George DUBOIS a modifié le statut : Nouveau → Reçu")
end

Alors("la liste est celle de l'état {string}") do |label|
  expect(page).to have_css("table caption", text: label)
  expect(page).to have_css("nav.fr-sidemenu a[aria-current='page']", text: label)
end

# Le fichier tel que l'amont le sert, sous son nom, en pièce jointe et jamais dans la page.
Alors("il obtient le fichier {string} en pièce jointe") do |filename|
  attachment = e2e_attachment(filename)
  expect(page.response_headers["content-disposition"]).to eq(
    "attachment; filename=\"#{filename}\"; filename*=UTF-8''#{filename}"
  )
  expect(page.response_headers["content-type"]).to start_with("application/octet-stream")
  expect(page.body.b).to eq(HubApiV1::Testing::Factories.attachment_body_for(attachment))
end

# Le plafond d'événements est un relevé de l'amont, pas un contrat : le fake sait le poser, les
# scénarios n'ont pas à connaître le nombre.
Étantdonné("l'historique du télédossier {string} est saturé") do |number|
  HubApiV1.client.saturate_case(e2e_delivery(number).id)
end

Alors("l'historique porte {string}") do |sentence|
  expect(page).to have_css("li", text: sentence)
end

Alors("il voit que la pièce ne peut pas être remise") do
  expect(page).to have_css("h1", text: "Cette pièce ne peut pas être remise")
end

Alors("il obtient une page introuvable, sans que le dossier lui soit montré") do
  expect(page).to have_text("Page introuvable")
  expect(page).to have_no_text("DGS-AEC-0000000000002-01")
end

Quand("il finalise le traitement du télédossier") do
  select("Traité", from: "Nouvel état")
  click_button("Enregistrer")
end

Quand("il le marque reçu") do
  within(".fr-callout") { click_button("Marquer comme reçu") }
end

# Le badge dit déjà « Reçu » : l'absence du bouton n'est pas vide de sens.
Alors("on ne lui propose plus de le marquer reçu") do
  expect(page).to have_css(".fr-badge", text: "Reçu")
  expect(page).to have_no_button("Marquer comme reçu")
end

Alors("il voit le télédossier au statut {string}") do |state|
  expect(page).to have_css(".fr-badge", text: state)
end

# L'auteur est publié : l'émetteur du dossier le lit. Le nom exact, donc, pas la seule phrase.
Alors("l'historique porte le changement signé {string}") do |author|
  expect(page).to have_text("#{author} a modifié le statut")
end

# Fermer appartient à l'émetteur : jamais proposé. Le formulaire doit exister pour que
# l'absence de « Clos » dise quelque chose.
Alors("il ne peut pas clore le télédossier") do
  expect(page).to have_select("Nouvel état")
  expect(page).to have_no_select("Nouvel état", with_options: ["Clos"])
end

Alors("il voit le flux nommé {string}") do |name|
  expect(page).to have_text(name)
end

# --- Archive des pièces ------------------------------------------------------------------------

# Deux pièces reçues, dont un `.xml` qui doit partir comme les autres, et une en attente.
E2E_PARTIALLY_RECEIVED_ATTACHMENTS = [
  {id: "d1111111-1111-1111-1111-111111111111", filename: "certificat.pdf"},
  {id: "d2222222-2222-2222-2222-222222222222", filename: "flux.xml", content_type: "application/xml"},
  {id: "d3333333-3333-3333-3333-333333333333", filename: "acte.pdf", state: :pending}
].freeze

def e2e_archive_attachment(filename)
  build_v2_attachment(E2E_PARTIALLY_RECEIVED_ATTACHMENTS.find { |attributes| attributes[:filename] == filename })
end

Étantdonné("l'API amont sert aussi un télédossier {string} dont deux pièces sur trois sont reçues") do |number|
  attachments = E2E_PARTIALLY_RECEIVED_ATTACHMENTS.map { |attributes| build_v2_attachment(attributes) }
  HubApiV1.client.add_case(e2e_delivery(number, data_package: build_v2_data_package(attachments:)))
end

Étantdonné("l'API amont sert aussi un télédossier {string} dont aucune pièce n'est reçue") do |number|
  HubApiV1.client.add_case(e2e_delivery(number, data_package: build_v2_data_package(
    attachments: [build_v2_attachment(filename: "acte.pdf", state: :pending)]
  )))
end

Alors("la pièce {string} est signalée {string}") do |filename, state|
  expect(page.find("tr", text: filename)).to have_css("p.fr-badge", text: state)
end

Quand("il télécharge l'archive {string}") do |label|
  click_link label
end

# Le nom de l'archive porte la minute du clic, à l'heure de Paris.
Quand("il télécharge l'archive {string} le {string}") do |label, instant|
  travel_to(Time.find_zone("Europe/Paris").strptime(instant, "%d/%m/%Y %H:%M")) { click_link label }
end

Alors("il obtient l'archive {string} avec les pièces {string}") do |archive, filenames|
  name = File.basename(archive, ".zip")
  expect(page.response_headers["content-disposition"]).to eq(
    "attachment; filename=\"#{archive}\"; filename*=UTF-8''#{archive}"
  )
  expect(page.response_headers["content-type"]).to eq("application/zip")
  entries = Zip::File.open_buffer(StringIO.new(page.body.b)).entries
    .map { |entry| [entry.name, entry.get_input_stream.read.b] }
  expect(entries).to eq(filenames.split(", ").map do |filename|
    ["#{name}/#{filename}", HubApiV1::Testing::Factories.attachment_body_for(e2e_archive_attachment(filename))]
  end)
end

Alors("aucune archive n'est proposée") do
  expect(page).to have_no_css("a[href$='/archive']")
  expect(page).to have_no_text("ZIP")
end

Alors("il voit que l'archive ne peut pas être remise") do
  expect(page.status_code).to eq(409)
  expect(page.response_headers["content-type"]).to start_with("text/html")
  expect(page.response_headers).not_to have_key("content-disposition")
  expect(page).to have_css("h1", text: "L'archive ne peut pas être remise")
end
