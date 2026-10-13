# frozen_string_literal: true

require "rails_helper"

# Controller spec (et non request spec) : en test/dev le serveur de fichiers
# statiques sert public/404.html & co. en 200, masquant les routes dynamiques.
# Le controller spec court-circuite ce middleware et teste le rendu DSFR réel.
RSpec.describe Portail::ErrorsController, type: :controller do
  render_views

  describe "GET #not_found" do
    it "renders the DSFR 404 page" do
      get :not_found

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Page introuvable")
      expect(response.body).to include("fr-footer")
    end

    # Le format vient de l'extension de l'URL d'origine : `/backup.zip` arrive ici en `zip`.
    %i[zip gzip json xml].each do |format|
      it "renders the DSFR 404 page in HTML for a #{format} request" do
        get :not_found, format: format

        expect(response).to have_http_status(:not_found)
        expect(response.media_type).to eq("text/html")
        expect(response.body).to include("Page introuvable")
      end
    end
  end

  describe "GET #unprocessable_entity" do
    it "renders the DSFR 422 page" do
      get :unprocessable_entity

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Requête invalide")
    end
  end

  describe "GET #internal_server_error" do
    it "renders the DSFR 500 page" do
      get :internal_server_error

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to include("Une erreur est survenue")
    end

    it "renders the DSFR 500 page in HTML for a non-HTML format" do
      get :internal_server_error, format: :json

      expect(response).to have_http_status(:internal_server_error)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Une erreur est survenue")
    end
  end

  it "renders every error page without querying the database, even for a signed-in agent" do
    session[:provider_session_id] = create(:provider_session).id
    queries = []
    record_query = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }

    ActiveSupport::Notifications.subscribed(record_query, "sql.active_record") do
      get :not_found
      get :unprocessable_entity
      get :internal_server_error
    end

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to include("Une erreur est survenue")
    expect(queries).to eq([])
  end
end
