# frozen_string_literal: true

require "rails_helper"

# Le rendu de chaque page, statut par statut. Le parcours d'une exception jusqu'à ces pages est
# couvert par spec/requests/portail/errors_spec.rb.
RSpec.describe Portail::ErrorsController, type: :controller do
  render_views

  describe "GET #show" do
    pages = {
      "400" => {status: :bad_request, heading: "Requête mal formée"},
      "404" => {status: :not_found, heading: "Page introuvable"},
      "406" => {status: :not_acceptable, heading: "Format non disponible"},
      "422" => {status: :unprocessable_content, heading: "Requête invalide"},
      "500" => {status: :internal_server_error, heading: "Une erreur est survenue"}
    }

    pages.each do |code, page|
      it "renders the DSFR #{code} page" do
        get :show, params: {status: code}

        expect(response).to have_http_status(page[:status])
        expect(response.body).to include(page[:heading], "fr-footer")
      end
    end

    # Rails et les gems décident des statuts levés : un statut sans page dédiée garde le sien.
    fallbacks = {
      "405" => {status: :method_not_allowed, heading: "Requête impossible"},
      "501" => {status: :not_implemented, heading: "Une erreur est survenue"}
    }

    fallbacks.each do |code, page|
      it "renders the generic DSFR page of its family for a #{code}" do
        get :show, params: {status: code}

        expect(response).to have_http_status(page[:status])
        expect(response.body).to include(page[:heading], "fr-footer")
      end
    end

    # Le format vient de l'extension de l'URL d'origine : `/backup.zip` arrive ici en `zip`.
    %i[zip gzip json xml].each do |format|
      it "renders the DSFR page in HTML for a #{format} request" do
        get :show, params: {status: "404"}, format: format

        expect(response).to have_http_status(:not_found)
        expect(response.media_type).to eq("text/html")
        expect(response.body).to include("Page introuvable")
      end
    end
  end

  it "renders error pages without querying the database, even for a signed-in agent" do
    session[:provider_session_id] = create(:provider_session).id
    queries = []
    record_query = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(record_query, "sql.active_record") do
      get :show, params: {status: "404"}
      get :show, params: {status: "500"}
    end

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include("Une erreur est survenue")
    expect(queries).to eq([])
  end
end
