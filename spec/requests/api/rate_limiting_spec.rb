require "rails_helper"

RSpec.describe "API rate limiting", type: :request do
  describe "token endpoint" do
    before { API::TokensController.cache_store.clear }

    it "throttles credential guessing by IP" do
      11.times { post "/api/oauth/token" }

      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)).to eq("error" => "rate_limited")
    end

    it "does not throttle under the limit" do
      10.times { post "/api/oauth/token" }

      expect(response).not_to have_http_status(:too_many_requests)
    end

    it "does not count one address against another" do
      10.times { post "/api/oauth/token" }
      post "/api/oauth/token", env: {"REMOTE_ADDR" => "203.0.113.7"}

      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "authenticated endpoints" do
    before { API::BaseController.cache_store.clear }

    it "throttles a runaway caller and identifies it by its credential" do
      301.times { get "/api/ping" }

      expect(response).to have_http_status(:too_many_requests)
      expect(JSON.parse(response.body)).to eq("error" => "rate_limited")
    end

    it "does not count one caller against another" do
      300.times { get "/api/ping" }
      get "/api/ping", headers: {"Authorization" => "Bearer another-caller"}

      expect(response).not_to have_http_status(:too_many_requests)
    end
  end
end
