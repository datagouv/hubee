# frozen_string_literal: true

require "rails_helper"

# De bout en bout : l'agent qu'un système interne enregistre est celui que la connexion retrouve.
# Le référentiel et ProConnect sont bouchonnés, la chaîne V2 entre les deux ne l'est pas.
RSpec.describe "Agent registered through the internal API", type: :request do
  # Le jeton s'obtient comme docs/API.md le dit à l'appelant : sans scope.
  def register(role:, data_stream_codes:)
    application = create(:oauth_application, :with_agent_registration_right)
    post "/api/oauth/token", params: {
      grant_type: "client_credentials", client_id: application.uid, client_secret: application.plaintext_secret
    }
    token = JSON.parse(response.body).fetch("access_token")
    stub_hub_api_organization_found(
      siret: ProConnectTestHelper::TEST_SIRET, type: "SI", branch_code: ProConnectTestHelper::TEST_INSEE_CODE
    )
    data_stream_codes.each { stub_hub_api_v2_data_stream(code: it) }

    post "/api/internal/agents", headers: {"Authorization" => "Bearer #{token}"}, as: :json, params: {
      agent: {
        email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin",
        membership: {
          siret: ProConnectTestHelper::TEST_SIRET, insee_code: ProConnectTestHelper::TEST_INSEE_CODE,
          role:, data_stream_codes:
        }
      }
    }
    expect(response).to have_http_status(:created)
  end

  def sign_in_and_land
    mock_proconnect(sub: "sub-alice", email: "alice.martin@ville.fr")
    proconnect_callback
    follow_redirect!
    follow_redirect!
  end

  it "lets a member habilitated on a data stream sign in and see that data stream only" do
    register(role: "member", data_stream_codes: ["CERTDC"])
    stub_organisation_subscriptions
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
      .with(hash_including(data_stream_codes: ["CERTDC"]))
      .and_return(build(:portail_delivery_list, deliveries: [build(:portail_delivery_summary)]))

    sign_in_and_land

    expect(response).to have_http_status(:success)
    expect(request.path).to eq(teledossiers_path)
    page = Capybara.string(response.body)
    expect(page).to have_text("Connecté en tant que Alex (alice.martin@ville.fr)")
    expect(page).to have_text("DGS-CERTDC-0000000000001-01")
  end

  it "lets a local administrator habilitated on a data stream sign in, filtered on it" do
    register(role: "local_administrator", data_stream_codes: ["CERTDC"])
    expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list))
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
      .with(hash_including(data_stream_codes: ["CERTDC"]))
      .and_return(build(:portail_delivery_list))

    sign_in_and_land

    expect(response).to have_http_status(:success)
    expect(request.path).to eq(teledossiers_path)
    expect(Capybara.string(response.body)).to have_link("Abonnements")
  end

  # Le cas de hub-api : l'administrateur local déclaré à l'abonnement a accès à tous les flux.
  it "lets a local administrator without habilitation sign in, unfiltered" do
    register(role: "local_administrator", data_stream_codes: [])
    expect(Portail::HubAPI::Subscriptions).to receive(:list).and_return(build(:portail_subscription_list))
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
      .with(hash_including(data_stream_codes: []))
      .and_return(build(:portail_delivery_list))

    sign_in_and_land

    expect(response).to have_http_status(:success)
    expect(request.path).to eq(teledossiers_path)
    expect(Capybara.string(response.body)).to have_link("Abonnements")
  end
end
