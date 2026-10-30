require "rails_helper"

# Aucune route interne n'existe encore : une sonde est dessinée le temps de l'exemple, déclarée
# comme dans config/routes.rb (contrainte sur le namespace, attrape-tout derrière).
RSpec.describe "API internal namespace", type: :request do
  around do |example|
    Rails.application.routes.draw do
      namespace :api do
        namespace :internal, constraints: API::Internal::AllowedNetwork.new(Rails.configuration.x.api_internal_allowed_ips) do
          get "sonde", to: "/api/pings#show"
        end

        match "(*path)", to: "errors#not_found", via: :all, format: false
      end
    end
    example.run
  ensure
    Rails.application.reload_routes!
  end

  it "lets an allowed address reach the route, the token being checked afterwards" do
    get "/api/internal/sonde", env: {"REMOTE_ADDR" => "127.0.0.1"}

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
  end

  {
    "without a token" => {},
    "with a forged X-Forwarded-For" => {"X-Forwarded-For" => "127.0.0.1"},
    "with a forged Forwarded header" => {"Forwarded" => "for=127.0.0.1"}
  }.each do |label, headers|
    it "answers a refused address the same JSON 404 as an unknown URL (#{label})" do
      get "/api/internal/sonde", headers:, env: {"REMOTE_ADDR" => "203.0.113.10"}

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq("application/json")
      expect(JSON.parse(response.body)).to eq("error" => "Ressource introuvable.")
    end
  end
end
