# frozen_string_literal: true

require "rails_helper"

# Ces exemples bouchonnent Portail::HubAPI ; la traversée de la gem est éprouvée dans le spec de la
# frontière. Les identifiants s'affichent dans le détail de l'abonnement : en Turbo Stream au clic,
# en page entière sans JavaScript.
RSpec.describe "Portail::Subscriptions::Credentials", type: :request do
  let(:path) { "/abonnements/550e8400-e29b-41d4-a716-446655440000/identifiants" }

  def post_for_stream = post(path, headers: {"Accept" => "text/vnd.turbo-stream.html, text/html"})

  def api_detail(**subscription) = build(:portail_subscription_detail,
    subscription: build(:portail_subscription, access_mode: "api", **subscription))

  def served_credentials = Portail::Subscription::Credentials.new(client_id: "client-42", client_secret: "s3cr3t-api")

  def stream = Capybara.string(response.body)

  # Le HTML porté par le stream : l'analyseur range le contenu d'un <template> hors de l'arbre que
  # Capybara parcourt, d'où une lecture du contenu brut avant analyse.
  def streamed_html = Capybara.string(response.body[%r{<template>(.*)</template>}m, 1].to_s)

  it "redirects a signed-out visitor to the home page" do
    post path

    expect(response).to redirect_to(root_path)
  end

  # Le rôle × habilitation entier : seul le rôle ouvre la consultation.
  context "reading perimeter" do
    it "streams the credentials to a local administrator habilitated on one data stream" do
      agent = sign_in_local_administrator(data_stream_codes: ["CERTDC"])
      expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
      expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)

      post_for_stream

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(stream).to have_css('turbo-stream[action="replace"][target="subscription-credentials"]', visible: :all)
      revealed = streamed_html.find("[data-turbo-temporary]")
      expect(revealed).to have_field("Identifiant client (client_id)", with: "client-42", readonly: true)
      expect(revealed).to have_field("Secret client (client_secret)", with: "s3cr3t-api", readonly: true)
      expect(Event.sole).to have_attributes(event_type: "subscription.credentials_revealed",
        eventable: Membership.find_by!(agent: agent))
    end

    it "streams the credentials to a local administrator without habilitation" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
      expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)

      post_for_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include("client-42", "s3cr3t-api")
    end

    it "refuses a member habilitated on a data stream before any upstream read" do
      sign_in_member(data_stream_codes: ["CERTDC"])
      expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      post_for_stream

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page introuvable")
      expect(Event.count).to eq(0)
    end

    it "refuses a member without habilitation before any upstream read" do
      sign_in_member(data_stream_codes: [])
      expect(Portail::HubAPI::Subscriptions).not_to receive(:find)
      expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

      post_for_stream

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page introuvable")
    end
  end

  it "renders the whole detail with the credentials when JavaScript is off" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)

    post path

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq("text/html")
    page = Capybara.string(response.body)
    expect(page).to have_css("h1", text: "CERTDC")
    section = page.find("#subscription-credentials")
    expect(section).to have_field("Identifiant client (client_id)", with: "client-42", readonly: true)
    expect(section).to have_field("Secret client (client_secret)", with: "s3cr3t-api", readonly: true)
  end

  # La section remplacée retire le bouton qui avait le focus : l'arrivée des identifiants doit
  # être annoncée, et le focus posé dessus.
  it "announces the credentials and moves the focus onto them" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)

    post path

    expect(response).to have_http_status(:success)
    section = Capybara.string(response.body).find("#subscription-credentials")
    expect(section).to have_css('.fr-alert[role="alert"]', text: "Ne les transmettez qu'aux personnes")
    expect(section).to have_css("input#subscription-client-id[autofocus]")
  end

  # Turbo retire le bloc temporaire de sa copie de la page : au retour par « précédent », il ne
  # reste que ce qui est hors de ce bloc, qui doit permettre une nouvelle consultation.
  it "keeps the reveal button outside the block Turbo drops from its cache" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)

    post path

    expect(response).to have_http_status(:success)
    section = Capybara.string(response.body).find("#subscription-credentials")
    expect(section).to have_css("[data-turbo-temporary] #subscription-client-secret")
    expect(section).to have_css(".subscription-credentials__prompt", visible: :all)
    expect(section.find(".subscription-credentials__prompt", visible: :all))
      .to have_button("Afficher les identifiants", visible: :all)
    expect(section).not_to have_css("[data-turbo-temporary] .subscription-credentials__prompt", visible: :all)
  end

  it "answers not found for a subscription served for another organisation, without reading credentials" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find)
      .and_return(build(:portail_subscription_detail,
        subscription: build(:portail_subscription, :of_another_organisation, access_mode: "api")))
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    post_for_stream

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page introuvable")
  end

  it "answers not found for a portal-mode subscription, without reading credentials" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(build(:portail_subscription_detail))
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    post_for_stream

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page introuvable")
  end

  it "answers not found for an unknown subscription" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_raise(Portail::HubAPI::NotFound)

    post_for_stream

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page introuvable")
  end

  # Chaque motif a son message ; aucun code technique de l'amont n'est montré tel quel.
  {
    "a client the upstream cannot single out" => {reason: :ambiguous_client, text: "support@hubee.numerique.gouv.fr"},
    "an inactive subscription" => {reason: :not_active, text: "pas actif"}
  }.each do |name, refusal|
    it "explains the refusal for #{name} without exposing the upstream reason" do
      sign_in_local_administrator
      expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
      expect(Portail::HubAPI::Subscriptions).to receive(:credentials)
        .and_raise(Portail::HubAPI::CredentialsRefused.new(refusal[:reason]))

      post_for_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(stream).to have_css('turbo-stream[target="subscription-credentials"]', visible: :all)
      expect(response.body).to include(refusal[:text])
      expect(response.body).not_to include(refusal[:reason].to_s)
      expect(Event.count).to eq(0)
    end
  end

  # Le bouton qui avait le focus disparaît : le refus doit être annoncé, et recevoir le focus.
  it "announces a refusal and moves the focus onto it" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials)
      .and_raise(Portail::HubAPI::CredentialsRefused.new(:not_active))

    post path

    expect(response).to have_http_status(:unprocessable_content)
    section = Capybara.string(response.body).find("#subscription-credentials")
    expect(section).to have_css('.fr-alert[role="status"][tabindex="-1"][autofocus]', text: "pas actif")
  end

  it "shows the unavailable page when the upstream is down" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_raise(Portail::HubAPI::Unavailable)

    post_for_stream

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("indisponible")
  end

  it "never writes the secret to the logs" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)

    events = capture_semantic_logger_events { post_for_stream }

    expect(response).to have_http_status(:success)
    expect(events).not_to be_empty
    events.each do |event|
      expect([event.message, event.payload, event.named_tags].to_s).not_to include("s3cr3t-api")
    end
  end

  # Sentry reçoit ce que le code signale par Rails.error.report : c'est ici l'échec de la trace,
  # signalé pendant que les identifiants sont en mémoire.
  it "never reports the secret to the error tracker" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)
    expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
    reports = []
    subscriber = Class.new { define_method(:report) { |error, **details| reports << [error, error.message, details] } }.new
    Rails.error.subscribe(subscriber)

    begin
      post_for_stream
    ensure
      Rails.error.unsubscribe(subscriber)
    end

    expect(response).to have_http_status(:service_unavailable)
    expect(reports).not_to be_empty
    expect(reports.inspect).not_to include("s3cr3t-api")
  end

  # Sentry joint à chaque erreur les notifications de la requête, réduites aux clés de sa liste :
  # le même tri, appliqué ici à une consultation réussie.
  it "never leaves the secret in the error tracker's breadcrumbs" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)
    allowed_keys = Sentry::Rails::ACTIVE_SUPPORT_LOGGER_SUBSCRIPTION_ITEMS_DEFAULT
    breadcrumbs = []
    subscription = ActiveSupport::Notifications.subscribe(/.*/) do |name, _started, _finished, _id, data|
      breadcrumbs << [name, data.slice(*allowed_keys[name])] if allowed_keys.key?(name) && data.is_a?(Hash)
    end

    begin
      post_for_stream
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end

    expect(response).to have_http_status(:success)
    expect(breadcrumbs.map(&:first)).to include("process_action.action_controller", "render_partial.action_view")
    expect(breadcrumbs.inspect).not_to include("s3cr3t-api")
  end

  it "does not show the secret when the consultation cannot be recorded" do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).to receive(:find).and_return(api_detail)
    expect(Portail::HubAPI::Subscriptions).to receive(:credentials).and_return(served_credentials)
    expect(Event).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    post_for_stream

    expect(response).to have_http_status(:service_unavailable)
    expect(response.body).to include("indisponible")
    expect(response.body).not_to include("s3cr3t-api")
  end

  # Un lien copié ou un préchargement ne lit rien et ne laisse aucune trace. Exceptions rendues
  # comme en production : la route manquante y donne la 404 du portail.
  it "does not answer a GET on the credentials URL", :production_exceptions do
    sign_in_local_administrator
    expect(Portail::HubAPI::Subscriptions).not_to receive(:credentials)

    get path

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Page introuvable")
    expect(Event.count).to eq(0)
  end
end
