require "rails_helper"

RSpec.describe "API::Pings", type: :request do
  subject(:make_request) { get "/api/ping", headers: headers }

  let(:application) { create(:oauth_application, name: "hub-api") }
  let(:access_token) { create(:oauth_access_token, application: application) }
  let(:headers) { {"Authorization" => "Bearer #{access_token.plaintext_token}"} }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/ping" do
    context "with a valid token" do
      it "answers ok" do
        make_request

        expect(response).to have_http_status(:ok)
        expect(json).to eq("status" => "ok")
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
      let(:headers) { {} }

      it "refuses with a uniform 401" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(json).to eq("error" => "invalid_token")
      end
    end

    context "with an unknown token" do
      let(:headers) { {"Authorization" => "Bearer unknown-token"} }

      it "refuses with the same uniform 401" do
        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(json).to eq("error" => "invalid_token")
      end
    end

    context "with an expired token" do
      it "refuses with the same uniform 401" do
        expired_headers = headers

        travel 3.hours do
          get "/api/ping", headers: expired_headers

          expect(response).to have_http_status(:unauthorized)
          expect(json).to eq("error" => "invalid_token")
        end
      end
    end

    context "with a revoked token" do
      it "refuses with the same uniform 401" do
        headers
        access_token.revoke

        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(json).to eq("error" => "invalid_token")
      end
    end

    context "with a destroyed client" do
      it "refuses with the same uniform 401" do
        headers
        application.destroy!

        make_request

        expect(response).to have_http_status(:unauthorized)
        expect(json).to eq("error" => "invalid_token")
      end
    end
  end
end
