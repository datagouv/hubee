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
  end
end
