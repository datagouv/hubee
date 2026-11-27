# frozen_string_literal: true

require "rails_helper"

# La consultation des identifiants d'un abonnement API, au clic : une page à part, que le POST rend
# lui-même. Ces exemples bouchonnent Portail::HubAPI, sauf un qui traverse la gem : la traduction est
# éprouvée dans le spec de la frontière.
RSpec.describe "Portail::Subscriptions::CredentialConsultations", type: :request do
  let(:id) { "550e8400-e29b-41d4-a716-446655440000" }
  let(:path) { "/abonnements/#{id}/identifiants/consultations" }
  # Tiré au hasard : aucune chaîne qui ressemble à un secret dans le dépôt (GitGuardian), et une
  # spec de non-fuite qui ne peut pas passer sur une valeur connue.
  let(:secret_value) { SecureRandom.hex(16) }
  let(:credentials) do
    Portail::Subscription::Credentials.new(client_id: "SI-99999999911111-00001-CERTDC",
      client_secret: HubApiV1::Secret.new(secret_value))
  end

  def page = Capybara.string(response.body)

  # Le bouton de l'abonnement part hors Turbo : un formulaire ordinaire, dont le navigateur affiche
  # la réponse.
  def reveal = post(path)

  # Les issues de la copie, écrites d'avance dans des <template> : le parseur de Capybara (HTML4) en
  # écarte le contenu, Nokogiri en HTML5 le garde.
  def copy_outcomes(target, message)
    Nokogiri::HTML5(response.body).css("template[data-clipboard-target='#{target}'] #{message}").map { it.text.squish }
  end

  # La consultation est très sensible : l'administrateur local qui consulte vient de vérifier son
  # identité pour cet abonnement. Les exemples de « reauthentication » éprouvent le garde lui-même.
  def sign_in_with_proof(...)
    sign_in_local_administrator(...).tap { grant_reauthentication(purpose: "credentials:#{id}") }
  end

  def serve_detail(access_mode: "api", trait: nil, read_package: true)
    subscription = build(:portail_subscription, *trait, access_mode:, read_package:)
    allow(Portail::HubAPI::Subscriptions).to receive(:find).and_return(build(:portail_subscription_detail, subscription:))
  end

  def serve_credentials
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials)
      .with(id: id, siret: ProConnectTestHelper::TEST_SIRET, insee_code: ProConnectTestHelper::TEST_INSEE_CODE)
      .and_return(credentials)
  end

  it "redirects a signed-out visitor to the home page" do
    post path

    expect(response).to redirect_to(root_path)
  end

  # Rien n'est bouchonné en deçà de la frontière : les identifiants traversent la gem entière.
  it "reveals the credentials the upstream serves for the organisation" do
    sign_in_with_proof
    use_hub_api_fake_client
      .add_subscription(build_v2_subscription_detail(subscription: build_v2_subscription(access_mode: :api,
        organization: build_v2_recipient(siret: ProConnectTestHelper::TEST_SIRET,
          code_insee: ProConnectTestHelper::TEST_INSEE_CODE))))
      .add_subscription_credentials(subscription_id: id, credentials: build_v2_subscription_credentials(
        client_id: "SI-99999999911111-00001-CERTDC", client_secret: HubApiV1::Secret.new(secret_value)
      ))

    reveal

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq("text/html")
    expect(page).to have_css("h1", text: "Identifiants de connexion à l'API")
    expect(page).to have_link("Retour à l'abonnement", href: "/abonnements/#{id}")
    expect(response.body).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
  end

  # La copie passe par le script : sans lui, l'agent voit les identifiants masqués et sait pourquoi
  # les boutons ne font rien.
  it "says the copy needs JavaScript, for a browser without it" do
    sign_in_with_proof
    serve_detail
    serve_credentials

    reveal

    expect(Nokogiri::HTML5(response.body).css("noscript").text.squish)
      .to include("La copie des identifiants nécessite JavaScript.")
  end

  # De quoi reconnaître les identifiants, pas de quoi les lire par-dessus l'épaule : la valeur
  # entière n'est que dans la cible de la copie.
  # Des données affichées, pas un formulaire : une liste de définitions, sans champ où le clavier
  # s'arrêterait. Seuls les boutons de copie prennent le focus.
  it "lists both credentials masked and hands their whole value to the copy buttons" do
    sign_in_with_proof
    serve_detail
    serve_credentials

    reveal

    block = page.find("#subscription-credentials")
    expect(block).to have_text("Pour votre sécurité, seuls les 4 premiers caractères sont affichés.")
    expect(block).to have_css("dl dt", text: "Identifiant client (client_id)")
    expect(block).to have_css("dl dt", text: "Secret client (client_secret)")
    expect(block).to have_css("dl dd code", text: "SI-9••••••••")
    expect(block).to have_css("dl dd code", text: "#{secret_value.first(4)}••••••••")
    expect(block).not_to have_css("input")
    expect(block.native.to_html).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
    expect(block.text).not_to include(secret_value)
    expect(block).to have_css("[data-controller='clipboard'][data-clipboard-text-value='SI-99999999911111-00001-CERTDC'] " \
      "dd button[type='button'][data-action='clipboard#copy']", text: "Copier l'identifiant client")
    expect(block).to have_css("[data-controller='clipboard'][data-clipboard-text-value='#{secret_value}'] " \
      "dd button[type='button'][data-action='clipboard#copy']", text: "Copier le secret client")
    # Chaque bouton annonce sa zone de messages, vide : le script y insère l'issue de la copie, écrite
    # d'avance dans un <template>.
    %w[client-id client-secret].each do |key|
      expect(block).to have_css("button[aria-describedby='subscription-credentials-#{key}-messages']")
      expect(block).to have_css("#subscription-credentials-#{key}-messages.fr-messages-group[aria-live='polite']:empty",
        visible: :all)
    end
    expect(copy_outcomes("copied", ".fr-message--valid")).to eq(["Copié dans le presse-papiers."] * 2)
    expect(copy_outcomes("failed", ".fr-message--error")).to eq(["La copie n'a pas fonctionné. Réessayez ; " \
      "si le problème persiste, écrivez à support@hubee.numerique.gouv.fr."] * 2)
  end

  # Le rôle × habilitation entier : seul le rôle ouvre les identifiants.
  context "reading perimeter" do
    it "reveals the credentials to a local administrator habilitated on the data stream" do
      sign_in_with_proof(data_stream_codes: ["CERTDC"])
      serve_detail
      serve_credentials

      expect { reveal }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
    end

    it "reveals the credentials to a local administrator without habilitation" do
      sign_in_with_proof
      serve_detail
      serve_credentials

      expect { reveal }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(secret_value)
    end

    # Le garde refuse un membre avant toute lecture : une 404, le refus journalisé.
    it "refuses a member habilitated on the data stream before reading anything" do
      agent = sign_in_member(data_stream_codes: ["CERTDC"])
      expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      events = capture_semantic_logger_events { expect { reveal }.not_to change(Event, :count) }

      expect(response).to have_http_status(:not_found)
      expect(events).to include(be_a_semantic_logger_event(
        level: :info, message: "Décision d'accès",
        payload_includes: {event: "Portail::Access::Refusal", reason: :out_of_perimeter, agent_id: agent.id}
      ))
    end

    it "refuses a member without habilitation before reading anything" do
      sign_in_member(data_stream_codes: [])
      expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      expect { reveal }.not_to change(Event, :count)

      expect(response).to have_http_status(:not_found)
    end

    # La requête amont porte l'organisation ; l'amont n'est pas cru sur parole.
    it "refuses a subscription the upstream served for another organisation, without asking for its secret" do
      sign_in_with_proof
      serve_detail(trait: :of_another_organisation)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      events = capture_semantic_logger_events { reveal }

      expect(response).to have_http_status(:not_found)
      expect(events).to include(be_a_semantic_logger_event(
        level: :info, message: "Décision d'accès", payload_includes: {reason: :out_of_perimeter}
      ))
    end
  end

  it "refuses a portal subscription, without asking for a secret" do
    sign_in_with_proof
    serve_detail(access_mode: "portal")
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    reveal

    expect(response).to have_http_status(:not_found)
  end

  it "refuses an inactive API subscription, without asking for a secret" do
    sign_in_with_proof
    serve_detail(read_package: false)
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    reveal

    expect(response).to have_http_status(:not_found)
  end

  it "answers not found for a subscription the upstream does not serve" do
    sign_in_with_proof
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_raise(Portail::HubAPI::NotFound)

    reveal

    expect(response).to have_http_status(:not_found)
  end

  it "says the credentials cannot be provided, pointing to the HubEE team, when the upstream refuses" do
    sign_in_with_proof
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::CredentialsRefused)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:conflict)
    expect(page).to have_text("Les identifiants de cet abonnement ne peuvent pas être fournis automatiquement.")
    expect(page).to have_link("support@hubee.numerique.gouv.fr", href: "mailto:support@hubee.numerique.gouv.fr")
    expect(page).to have_link("Retour à l'abonnement", href: "/abonnements/#{id}")
  end

  # Supprimé entre la lecture du détail et le clic : la 404 du portail, comme sur le détail.
  it "answers not found when the subscription disappears before its credentials are read" do
    sign_in_with_proof
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::NotFound)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:not_found)
    expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
  end

  # Une panne, ou une route que hub-api refuse (403 tant qu'elle n'y est pas déployée) : ni passagère
  # à coup sûr, ni du ressort de l'agent. On ne promet pas un réessai immédiat, on oriente.
  it "says the credentials cannot be read for now, pointing to the support, when the upstream is failing" do
    sign_in_with_proof
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:service_unavailable)
    expect(page).to have_text("Les identifiants ne peuvent pas être lus pour le moment. Réessayez plus tard ; " \
      "si le problème persiste, écrivez à support@hubee.numerique.gouv.fr.")
    expect(page).to have_link("support@hubee.numerique.gouv.fr", href: "mailto:support@hubee.numerique.gouv.fr")
  end

  # La raison du POST : sans le jeton de la page, une requête forgée ailleurs au nom de l'agent
  # ne lit rien et ne trace rien.
  it "refuses a request without the page's CSRF token, before reading anything" do
    sign_in_with_proof
    expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)
    ActionController::Base.allow_forgery_protection = true

    expect { reveal }.not_to change(Event, :count)

    expect(response).to redirect_to(root_path)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  # Deux caches : celui du navigateur (en-tête) et celui de Turbo, qui garde une copie des pages qu'il
  # quitte et la réaffiche au retour arrière sans requête (balise). Le retour arrière est éprouvé de
  # bout en bout dans features/portail/abonnements.feature.
  it "keeps the response out of the browser's cache and out of Turbo's" do
    sign_in_with_proof
    serve_detail
    serve_credentials

    reveal

    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(page).to have_css("meta[name='turbo-cache-control'][content='no-cache']", visible: :all)
  end

  # Ce que redemande un retour arrière sur la page des identifiants : le bloc, jamais le secret. La
  # redirection ne passe par aucun garde : elle ne lit rien et ne consomme pas la preuve.
  it "brings a GET on the consultation address back to the credentials block, without reading or consuming" do
    sign_in_with_proof
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    expect { get path }.not_to change(Event, :count)

    expect(response).to have_http_status(:found)
    expect(response).to redirect_to("/abonnements/#{id}#identifiants")
    expect(ProviderSession.granted.sole.reauthentication_consumed_at).to be_nil
  end

  # L'identifiant est réencodé : des « .. » ou des « / » encodés ne mènent pas ailleurs sur le site.
  it "keeps the redirection on the subscription whatever the identifier carries" do
    get "/abonnements/..%2F..%2Fx/identifiants/consultations"

    expect(response).to redirect_to("/abonnements/..%2F..%2Fx#identifiants")
  end

  # Le secret n'est écrit qu'à un seul endroit : la réponse à l'agent qui l'a demandé.
  it "never writes the secret anywhere but the response" do
    sign_in_with_proof
    serve_detail
    serve_credentials

    events = capture_semantic_logger_events { reveal }

    expect(response.body).to include(secret_value)
    expect(events).not_to be_empty
    events.each { |event| expect([event.message, event.payload, event.exception].inspect).not_to include(secret_value) }
    expect(Event.last.metadata.to_json).not_to include(secret_value)
  end

  # Pas de trace, pas d'affichage : l'erreur est journalisée sans le secret. 422 : la réponse
  # que Rails associe à un enregistrement invalide.
  it "shows nothing when the consultation cannot be recorded", :production_exceptions do
    sign_in_with_proof
    serve_detail
    serve_credentials
    expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    events = capture_semantic_logger_events { reveal }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).not_to include(secret_value)
    logged = events.map { |event| [event.message, event.payload, event.exception].inspect }.join
    expect(logged).to include("ActiveRecord::RecordInvalid")
    expect(logged).not_to include(secret_value)
  end

  describe "reauthentication" do
    def sign_in_without_proof
      agent = create(:agent, provider_sub: "sub-admin")
      sign_in_via_proconnect(agent:)
      Membership.find_by!(agent:).update!(role: "local_administrator")
      agent
    end

    def expect_reauthentication_logout
      expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
        .and_return("https://proconnect.test/api/v2/session/end")
    end

    # Le garde part de la requête interceptée : l'abonnement et la page de retour en viennent.
    it "departs for a reauthentication without a proof, before reading anything upstream" do
      sign_in_without_proof
      expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)
      expect_reauthentication_logout

      expect { reveal }.not_to change(Event, :count)

      expect(response).to redirect_to("https://proconnect.test/api/v2/session/end")
      expect(session[:reauthentication]).to include("action" => "credentials",
        "purpose" => Portail::Access::Reauthentication.purpose(:credentials, id), "return_to" => "/abonnements/#{id}#identifiants")
    end

    # Un rechargement de la page des identifiants renvoie le POST : la preuve est déjà consommée.
    it "consumes the proof: a second consultation departs for a reauthentication again" do
      sign_in_with_proof
      serve_detail
      serve_credentials

      reveal
      expect(response).to have_http_status(:success)

      expect_reauthentication_logout
      reveal
      expect(response).to redirect_to("https://proconnect.test/api/v2/session/end")
    end

    it "does not take a proof obtained for another subscription" do
      sign_in_without_proof
      grant_reauthentication(purpose: Portail::Access::Reauthentication.purpose(:credentials, "another-subscription"))
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)
      expect_reauthentication_logout

      reveal

      expect(response).to redirect_to("https://proconnect.test/api/v2/session/end")
    end

    # De bout en bout : le clic, la réauthentification, le retour sur l'abonnement, puis le même clic.
    it "reveals the credentials when the agent clicks again after the reauthentication" do
      agent = sign_in_without_proof
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1-mfa")
      reauthenticate(from: path)
      expect(response).to redirect_to("/abonnements/#{id}#identifiants")
      serve_detail
      serve_credentials

      expect { reveal }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(secret_value)
    end
  end
end
