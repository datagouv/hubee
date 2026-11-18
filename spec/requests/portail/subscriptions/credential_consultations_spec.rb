# frozen_string_literal: true

require "rails_helper"

# La consultation des identifiants d'un abonnement API, au clic, en Turbo Stream. Ces exemples
# bouchonnent Portail::HubAPI, sauf un qui traverse la gem : la traduction est éprouvée dans le
# spec de la frontière.
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

  # Le bloc envoyé : Capybara ne lit pas le contenu d'un <template>.
  def page = Capybara.string(Nokogiri::HTML5.fragment(response.body).at_css("template").inner_html)

  def reveal = post(path, headers: {"Accept" => "text/vnd.turbo-stream.html"})

  # Les issues de la copie, écrites d'avance dans des <template> : le parseur de Capybara (HTML4) en
  # écarte le contenu, Nokogiri en HTML5 le garde.
  def copy_outcomes(target, message)
    Nokogiri::HTML5.fragment(response.body).css("template[data-clipboard-target='#{target}'] #{message}").map { it.text.squish }
  end

  # Dans ce fichier, l'administrateur local vient de vérifier son identité pour cet abonnement : la
  # consultation est très sensible. Les exemples de « reauthentication » éprouvent le garde lui-même.
  def sign_in_local_administrator(...)
    super.tap { grant_reauthentication(purpose: "credentials:#{id}") }
  end

  def serve_detail(access_mode: "api", trait: nil)
    subscription = build(:portail_subscription, *trait, access_mode:)
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
    sign_in_local_administrator
    use_hub_api_fake_client
      .add_subscription(build_v2_subscription_detail(subscription: build_v2_subscription(access_mode: :api,
        organization: build_v2_recipient(siret: ProConnectTestHelper::TEST_SIRET,
          code_insee: ProConnectTestHelper::TEST_INSEE_CODE))))
      .add_subscription_credentials(subscription_id: id, credentials: build_v2_subscription_credentials(
        client_id: "SI-99999999911111-00001-CERTDC", client_secret: HubApiV1::Secret.new(secret_value)
      ))

    reveal

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(Capybara.string(response.body))
      .to have_css("turbo-stream[action='replace'][target='subscription-credentials']", visible: :all)
    # Le bouton qui avait le focus disparaît : Turbo le porte sur le titre du bloc.
    expect(page).to have_css("#subscription-credentials h2[tabindex='-1'][autofocus]")
    expect(response.body).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
  end

  # De quoi reconnaître les identifiants, pas de quoi les lire par-dessus l'épaule : la valeur
  # entière n'est que dans la cible de la copie.
  it "masks both credentials in read-only fields and hands their whole value to the copy buttons" do
    sign_in_local_administrator
    serve_detail
    serve_credentials

    reveal

    block = page.find("#subscription-credentials")
    expect(block).to have_text("Pour votre sécurité, seuls les 4 premiers caractères sont affichés.")
    expect(block).to have_field("Identifiant client (client_id)", with: "SI-9••••••••", readonly: true)
    expect(block).to have_field("Secret client (client_secret)", with: "#{secret_value.first(4)}••••••••", readonly: true)
    expect(block.native.to_html).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
    expect(block.all("input").map(&:value).join).not_to include(secret_value)
    expect(block).to have_css("[data-controller='clipboard'][data-clipboard-text-value='SI-99999999911111-00001-CERTDC'] " \
      ".fr-input-wrap--action button[type='button'][data-action='clipboard#copy']", text: "Copier l'identifiant client")
    expect(block).to have_css("[data-controller='clipboard'][data-clipboard-text-value='#{secret_value}'] " \
      ".fr-input-wrap--action button[type='button'][data-action='clipboard#copy']", text: "Copier le secret client")
    # Chaque champ annonce sa zone de messages, vide : le script y insère l'issue de la copie, écrite
    # d'avance dans un <template>.
    %w[client-id client-secret].each do |key|
      expect(block).to have_css("input#subscription-credentials-#{key}" \
        "[aria-describedby='subscription-credentials-#{key}-messages']")
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
      sign_in_local_administrator(data_stream_codes: ["CERTDC"])
      serve_detail
      serve_credentials

      expect { reveal }.to change(Event, :count).by(1)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
    end

    it "reveals the credentials to a local administrator without habilitation" do
      sign_in_local_administrator
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
      sign_in_local_administrator
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
    sign_in_local_administrator
    serve_detail(access_mode: "portal")
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    reveal

    expect(response).to have_http_status(:not_found)
  end

  it "answers not found for a subscription the upstream does not serve" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_raise(Portail::HubAPI::NotFound)

    reveal

    expect(response).to have_http_status(:not_found)
  end

  it "says the credentials cannot be provided, pointing to the HubEE team, when the upstream refuses" do
    sign_in_local_administrator
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::CredentialsRefused)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:conflict)
    expect(page).to have_text("Les identifiants de cet abonnement ne peuvent pas être fournis automatiquement.")
    expect(page).to have_link("support@hubee.numerique.gouv.fr", href: "mailto:support@hubee.numerique.gouv.fr")
    expect(page).to have_css("#subscription-credentials h2[tabindex='-1'][autofocus]")
  end

  # Supprimé entre la lecture du détail et le clic : la 404 du portail, comme sur le détail.
  it "answers not found when the subscription disappears before its credentials are read" do
    sign_in_local_administrator
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::NotFound)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:not_found)
    expect(Capybara.string(response.body)).to have_css("h1", text: "Page introuvable")
  end

  # Une panne, ou une route que hub-api refuse (403 tant qu'elle n'y est pas déployée) : ni passagère
  # à coup sûr, ni du ressort de l'agent. On ne promet pas un réessai immédiat, on oriente.
  it "says the credentials cannot be read for now, pointing to the support, when the upstream is failing" do
    sign_in_local_administrator
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:service_unavailable)
    expect(page).to have_text("Les identifiants ne peuvent pas être lus pour le moment. Réessayez plus tard ; " \
      "si le problème persiste, écrivez à support@hubee.numerique.gouv.fr.")
    expect(page).to have_link("support@hubee.numerique.gouv.fr", href: "mailto:support@hubee.numerique.gouv.fr")
  end

  # Sans JavaScript, le formulaire part sans Turbo : on dit pourquoi, sans rien lire ni tracer.
  it "asks to turn JavaScript on when the request comes without Turbo, before reading anything" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    expect { post path }.not_to change(Event, :count)

    expect(response).to have_http_status(:not_acceptable)
    expect(response.media_type).to eq("text/html")
    page = Capybara.string(response.body)
    expect(page).to have_css("h1", text: "Activez JavaScript pour afficher les identifiants")
    expect(page).to have_link("Retour à l'abonnement", href: "/abonnements/#{id}")
  end

  # La raison du POST : sans le jeton de la page, une requête forgée ailleurs au nom de l'agent
  # ne lit rien et ne trace rien.
  it "refuses a request without the page's CSRF token, before reading anything" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)
    ActionController::Base.allow_forgery_protection = true

    expect { reveal }.not_to change(Event, :count)

    expect(response).to redirect_to(root_path)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  it "forbids caching the response" do
    sign_in_local_administrator
    serve_detail
    serve_credentials

    reveal

    expect(response.headers["Cache-Control"]).to include("no-store")
  end

  # Le secret n'est écrit qu'à un seul endroit : la réponse à l'agent qui l'a demandé.
  it "never writes the secret anywhere but the response" do
    sign_in_local_administrator
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
    sign_in_local_administrator
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
    end

    it "asks for a reauthentication without a proof, before reading anything upstream" do
      sign_in_without_proof
      expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      expect { reveal }.not_to change(Event, :count)

      expect(response).to have_http_status(:forbidden)
      expect(Capybara.string(response.body))
        .to have_css("turbo-stream[action='replace'][target='subscription-credentials']", visible: :all)
      expect(page).to have_css("form[action='/connexion/reauthentification'][data-turbo='false'] button",
        text: "Obtenir les identifiants")
      expect(page).to have_css("input[name='purpose'][value='credentials:#{id}']", visible: :all)
      expect(page).to have_css("input[name='return_to'][value='/abonnements/#{id}']", visible: :all)
    end

    it "consumes the proof: a second consultation asks again" do
      sign_in_local_administrator
      serve_detail
      serve_credentials

      reveal
      expect(response).to have_http_status(:success)

      reveal
      expect(response).to have_http_status(:forbidden)
    end

    it "refuses a proof obtained for another subscription" do
      sign_in_without_proof
      grant_reauthentication(purpose: "credentials:another-subscription")
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      reveal

      expect(response).to have_http_status(:forbidden)
    end
  end
end
