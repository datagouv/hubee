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
        expect(JSON.parse(response.body)).to eq("error" => "Ressource introuvable.")
      end
    end
  end

  describe "the routes declared before the catch-all" do
    it "still serves /api/ping" do
      get "/api/ping"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
    end

    it "still serves the token delivery" do
      post "/api/oauth/token", params: {grant_type: "client_credentials", client_id: "unknown-uid"}

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body)).to include("error" => "invalid_client")
    end
  end
end
