# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail errors", :production_exceptions, type: :request do
  it "renders the DSFR 404 page for an unknown URL" do
    get "/inconnue"

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Page introuvable", "fr-footer")
  end

  it "renders the DSFR 404 page for an unknown URL that only starts like the API" do
    get "/apidoc"

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Page introuvable")
  end

  it "renders the DSFR 404 page for an unknown URL with an unreadable query" do
    get "/inconnue?a[]=1&a[b]=2"

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Page introuvable", "fr-footer")
  end

  it "renders the DSFR 404 page for an unknown URL with an unreadable body" do
    post "/inconnue", params: "{illisible", headers: {"Content-Type" => "application/json"}

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Page introuvable", "fr-footer")
  end

  it "renders the DSFR 400 page for an unreadable query" do
    get "/?a[]=1&a[b]=2"

    expect(response).to have_http_status(:bad_request)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Requête mal formée", "fr-footer")
  end

  it "renders the DSFR 400 page for an unreadable body" do
    sign_in_via_proconnect(agent: create(:agent))

    patch "/teledossiers/1/etat", params: "{illisible", headers: {"Content-Type" => "application/json"}

    expect(response).to have_http_status(:bad_request)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Requête mal formée", "fr-footer")
  end

  it "renders the DSFR 406 page for an unreadable Accept header" do
    get "/connexion/echec", headers: {"Accept" => "illisible"}

    expect(response).to have_http_status(:not_acceptable)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Format non disponible", "fr-footer")
  end

  it "renders the DSFR unsupported browser page for an outdated browser" do
    get "/", headers: {"User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36"}

    expect(response).to have_http_status(:not_acceptable)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Navigateur non pris en charge", "fr-footer")
  end

  # Le serveur de fichiers statiques passe avant le routeur : un public/500.html répondrait en 200.
  it "renders the DSFR 500 page at its own address" do
    get "/500"

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include("Une erreur est survenue", "fr-footer")
  end

  it "renders the DSFR 500 page for an unexpected error, and reports it" do
    sign_in_via_proconnect(agent: create(:agent))
    expect(ProviderSession).to receive(:includes).and_raise(ActiveRecord::ConnectionNotEstablished)

    reported = errors_reported_during { get "/" }

    expect(response).to have_http_status(:internal_server_error)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Une erreur est survenue", "fr-footer")
    expect(reported).to contain_exactly(an_instance_of(ActiveRecord::ConnectionNotEstablished))
  end
end
