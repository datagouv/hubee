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
    expect(page).to have_css("#subscription-credentials code", text: secret_value)
    # Le bouton qui avait le focus disparaît : Turbo le porte sur le titre du bloc.
    expect(page).to have_css("#subscription-credentials h2[tabindex='-1'][autofocus]")
    expect(response.body).to include("SI-99999999911111-00001-CERTDC").and include(secret_value)
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

  # Le détail vient d'être servi : la route des identifiants manquante ne fait pas disparaître la page.
  it "says the credentials cannot be read for now when the upstream no longer finds them" do
    sign_in_local_administrator
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::NotFound)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:service_unavailable)
    expect(page).to have_text("Les identifiants ne peuvent pas être lus pour le moment.")
  end

  it "says the credentials cannot be read for now when the upstream is failing" do
    sign_in_local_administrator
    serve_detail
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    expect { reveal }.not_to change(Event, :count)

    expect(response).to have_http_status(:service_unavailable)
    expect(page).to have_text("Les identifiants ne peuvent pas être lus pour le moment.")
  end

  # Le bouton passe par Turbo : une autre requête ne crée pas de consultation.
  it "answers 406 to a non-Turbo request, before reading anything" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    expect { post path }.not_to change(Event, :count)

    expect(response).to have_http_status(:not_acceptable)
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
end
