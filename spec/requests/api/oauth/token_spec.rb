require "rails_helper"

RSpec.describe "API OAuth token endpoint", type: :request do
  subject(:request_token) { post "/api/oauth/token", params: params }

  let(:application) { create(:oauth_application) }
  let(:json) { JSON.parse(response.body) }
  let(:valid_params) do
    {
      grant_type: "client_credentials",
      client_id: application.uid,
      client_secret: application.plaintext_secret
    }
  end

  describe "POST /api/oauth/token" do
    context "with valid client credentials" do
      let(:params) { valid_params }

      it "delivers an opaque bearer token expiring in 2 hours, without refresh token" do
        request_token

        expect(response).to have_http_status(:ok)
        expect(json).to include(
          "access_token" => match(/\S{20,}/),
          "token_type" => "Bearer",
          "expires_in" => 7200
        )
        expect(json).not_to have_key("refresh_token")
      end
    end

    context "with a wrong client secret" do
      let(:params) { valid_params.merge(client_secret: "wrong-secret") }

      it "refuses with invalid_client" do
        request_token

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq("invalid_client")
      end
    end

    context "with an unknown client id" do
      let(:params) { valid_params.merge(client_id: "unknown-uid") }

      it "refuses with the same invalid_client error, without distinction" do
        request_token

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq("invalid_client")
      end
    end

    context "after a secret rotation" do
      it "refuses the previous secret" do
        previous_secret = application.plaintext_secret
        application.renew_secret
        application.save!

        post "/api/oauth/token", params: valid_params.merge(client_secret: previous_secret)

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq("invalid_client")
      end
    end

    context "with a destroyed client" do
      let(:params) { valid_params }

      it "refuses with invalid_client" do
        params
        application.destroy!

        request_token

        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]).to eq("invalid_client")
      end
    end

    context "with a grant type that is not enabled" do
      let(:params) { valid_params.merge(grant_type: "authorization_code") }

      it "refuses with unsupported_grant_type" do
        request_token

        expect(response).to have_http_status(:bad_request)
        expect(json["error"]).to eq("unsupported_grant_type")
      end
    end
  end
end
