require "rails_helper"

RSpec.describe "API::Pings", type: :request do
  subject(:make_request) { get "/api/ping", headers: headers }

  let(:application) { create(:oauth_application, name: "hub-api") }
  let(:access_token) { create(:oauth_access_token, application: application) }
  let(:headers) { {"Authorization" => "Bearer #{access_token.plaintext_token}"} }

  describe "GET /api/ping" do
    context "with a valid token" do
      it "answers ok" do
        make_request

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq("status" => "ok")
      end

      it "attributes the request to the client in the request log payload" do
        payloads = []
        callback = ->(_name, _start, _finish, _id, payload) { payloads << payload }

        ActiveSupport::Notifications.subscribed(callback, "process_action.action_controller") do
          make_request
        end

        expect(payloads.first[:api_client]).to eq("hub-api")
      end
    end

    context "without a token" do
      it "refuses with a uniform 401" do
        get "/api/ping"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
      end
    end

    context "with an unknown token" do
      it "refuses with the same uniform 401" do
        get "/api/ping", headers: {"Authorization" => "Bearer unknown-token"}

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
      end
    end

    context "with an expired token" do
      it "refuses with the same uniform 401" do
        expired_headers = headers

        travel 3.hours do
          get "/api/ping", headers: expired_headers

          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
        end
      end
    end

    context "with a revoked token" do
      it "refuses with the same uniform 401" do
        headers
        access_token.revoke

        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
      end
    end

    context "with a destroyed client" do
      it "refuses with the same uniform 401" do
        headers
        application.destroy!

        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "invalid_token")
      end
    end

    context "whatever the invalid token reason" do
      # Doorkeeper pose le header avant nos render options : il reprenait les
      # messages traduits et divulguait révoqué / expiré / inconnu.
      it "returns the same WWW-Authenticate header for expired, revoked and unknown tokens" do
        expired = travel_to(3.hours.ago) { create(:oauth_access_token, application: application) }
        revoked = create(:oauth_access_token, application: application)
        revoked_token = revoked.plaintext_token
        revoked.revoke

        www_authenticate_headers = [expired.plaintext_token, revoked_token, "unknown-token"].map do |token|
          get "/api/ping", headers: {"Authorization" => "Bearer #{token}"}

          expect(response).to have_http_status(:unauthorized)
          response.headers["WWW-Authenticate"]
        end

        # « acc_s » : Doorkeeper remplace les caractères non-ASCII par « _ » (RFC 6750).
        expect(www_authenticate_headers.uniq).to eq(
          [%(Bearer realm="Doorkeeper", error="invalid_token", error_description="Le token d'acc_s est invalide.")]
        )
      end
    end
  end
end
