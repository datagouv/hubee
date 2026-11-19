# frozen_string_literal: true

require "rails_helper"

# Un contrôleur anonyme, local à ce fichier : les gardes s'éprouvent sur un vrai cycle de requête, sans
# dépendre d'une action réelle ni de ce qu'elle autorise.
RSpec.describe API::Internal::V1::BaseController, type: :controller do
  controller(described_class) do
    # Un refus levé avant toute autorisation : son rendu ne doit pas déclencher verify_authorized.
    def index
      raise Pundit::NotAuthorizedError
    end

    def show
      authorize(:agent, :index?, policy_class: API::Internal::V1::AgentPolicy)
      head :ok
    end

    # Oublie d'autoriser : c'est ce que verify_authorized doit faire échouer.
    def create
      head :ok
    end

    # Une erreur rattrapée avant toute autorisation, comme une ressource introuvable.
    def destroy
      raise ActiveRecord::RecordNotFound
    end
  end

  def authenticate(application)
    request.headers["Authorization"] = "Bearer #{create(:oauth_access_token, application:).plaintext_token}"
  end

  it "answers a right the client lacks with a JSON 403" do
    authenticate(create(:oauth_application, :admin_portal))

    get :index

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end

  it "fails an action that forgets to authorize" do
    authenticate(create(:oauth_application, :admin_portal))

    expect { post :create }.to raise_error(Pundit::AuthorizationNotPerformedError)
  end

  it "lets through an action that authorizes" do
    authenticate(create(:oauth_application, :admin_portal))

    get :show, params: {id: "1"}

    expect(response).to have_http_status(:ok)
  end

  # Le 401 de Doorkeeper arrête la chaîne avant l'action : il n'y a rien à autoriser.
  it "answers 401 without a token, before any authorization" do
    post :create

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to eq("error" => "invalid_token", "message" => "Le jeton d'accès est absent, inconnu, expiré ou révoqué.")
  end

  it "answers 404 for an error rescued before any authorization" do
    authenticate(create(:oauth_application, :admin_portal))

    delete :destroy, params: {id: "1"}

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to eq("error" => "not_found", "message" => "Ressource introuvable.")
  end

  # Le refus de Pundit est rendu par son rescue_from : verify_authorized ne s'y ajoute pas.
  it "answers 403 to a client without the right" do
    authenticate(create(:oauth_application))

    get :show, params: {id: "1"}

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end
end
