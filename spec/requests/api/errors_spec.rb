require "rails_helper"

RSpec.describe "API errors", type: :request do
  describe "an unknown URL under /api" do
    {
      "GET /api/inconnu" => {verb: :get, path: "/api/inconnu"},
      "POST on a nested path" => {verb: :post, path: "/api/inconnu/sous/chemin"},
      "a frozen v1 route" => {verb: :get, path: "/api/v1/organizations"},
      "a path with an extension" => {verb: :get, path: "/api/inconnu.zip"},
      "the /api root" => {verb: :get, path: "/api"}
    }.each do |label, request_case|
      it "answers a JSON 404 without asking for a token (#{label})" do
        public_send(request_case[:verb], request_case[:path])

        expect(response).to have_http_status(:not_found)
        expect(response.media_type).to eq("application/json")
        expect(JSON.parse(response.body)).to eq("error" => "not_found", "message" => "Ressource introuvable.")
      end
    end
  end

  describe "the routes declared before the catch-all" do
    it "still serves /api/ping" do
      get "/api/ping"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq("error" => "invalid_token", "message" => "Le jeton d'accès est absent, inconnu, expiré ou révoqué.")
    end

    it "still serves the token delivery" do
      post "/api/oauth/token", params: {grant_type: "client_credentials", client_id: "unknown-uid"}

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to include("error" => "invalid_client")
    end
  end

  describe "an exception under /api", :production_exceptions do
    it "answers a malformed JSON body with a JSON 400" do
      post "/api/oauth/token", params: "{pas du json", headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to eq("error" => "bad_request", "message" => "La requête est mal formée.")
    end

    it "answers a malformed query string with a JSON 400" do
      get "/api/ping?flux[]=1&flux[code]=2"

      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to eq("error" => "bad_request", "message" => "La requête est mal formée.")
    end

    it "answers an unexpected error with a JSON 500, and reports it" do
      expect(Doorkeeper::AccessToken).to receive(:by_token).at_least(:once).and_raise(ActiveRecord::ConnectionNotEstablished)

      reported = errors_reported_during { get "/api/ping", headers: {"Authorization" => "Bearer jeton"} }

      expect(response).to have_http_status(:internal_server_error)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to eq("error" => "internal_server_error", "message" => "Une erreur est survenue.")
      expect(reported).to contain_exactly(an_instance_of(ActiveRecord::ConnectionNotEstablished))
    end

    it "keeps the status Rails gives an exception, with the generic message" do
      expect(Doorkeeper::AccessToken).to receive(:by_token).at_least(:once).and_raise(ActiveRecord::RecordInvalid)

      get "/api/ping", headers: {"Authorization" => "Bearer jeton"}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to eq("error" => "unprocessable_content", "message" => "Une erreur est survenue.")
    end
  end
end
