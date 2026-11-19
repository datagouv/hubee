# frozen_string_literal: true

require "rails_helper"

# De bout en bout : ce que le portail d'administration change par l'API interne prend effet sur
# le portail à la prochaine requête de l'agent, sans qu'il ait à se reconnecter. Seuls ProConnect
# et le référentiel sont bouchonnés ; l'API, la session et l'autorisation du portail ne le sont pas.
RSpec.describe "Agent management through the internal API, seen from the portal", type: :request do
  let(:admin_portal) { create(:oauth_application, :admin_portal) }

  # Les abonnements et le flux de l'organisation sont le décor commun du portail.
  before do
    stub_organisation_subscriptions
    stub_data_stream
  end

  def membership_path_for(agent)
    "/api/internal/v1/agents/#{agent.id}/memberships/#{Membership.find_by!(agent:).id}"
  end

  # Le portail liste les télédossiers de l'organisation, filtrés sur les habilitations de l'agent : au moins
  # à la première requête, que l'agent fait toujours avec son accès.
  def expect_empty_deliveries
    expect(Portail::HubAPI::Deliveries).to receive(:list).at_least(:once).and_return(build(:portail_delivery_list))
  end

  it "asks the second factor at the next request of a member promoted to local administrator" do
    expect_empty_deliveries
    agent = create(:agent, provider_sub: "sub-membre")
    sign_in_via_proconnect(agent:, amr: ["pwd"])
    create(:data_stream_access, membership: Membership.find_by!(agent:), data_stream_code: "CERTDC")
    get teledossiers_path
    expect(response).to have_http_status(:success)

    patch membership_path_for(agent), params: {membership: {role: "local_administrator"}}, headers: bearer(admin_portal), as: :json
    expect(response).to have_http_status(:success)

    get teledossiers_path

    expect(response).to redirect_to(step_up_path)
  end

  it "closes the access at the next request when the membership is withdrawn" do
    expect_empty_deliveries
    agent = sign_in_member
    get teledossiers_path
    expect(response).to have_http_status(:success)

    delete membership_path_for(agent), headers: bearer(admin_portal), as: :json
    expect(response).to have_http_status(:no_content)

    get teledossiers_path

    expect(response).to redirect_to(root_path)
  end

  it "stops serving a withdrawn data stream at the next request" do
    agent = sign_in_member
    # Le portail ne sert que les flux que l'organisation reçoit : elle est abonnée aux deux.
    stub_organisation_subscriptions({"CERTDC" => nil, "DECES" => nil})
    stub_hub_api_v2_data_stream(code: "DECES")
    expect(Portail::HubAPI::Deliveries).to receive(:list)
      # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
      .with(hash_including(data_stream_codes: ["CERTDC"]))
      .and_return(build(:portail_delivery_list))
    get teledossiers_path
    expect(response).to have_http_status(:success)

    patch membership_path_for(agent), params: {membership: {data_stream_codes: ["DECES"]}}, headers: bearer(admin_portal), as: :json
    expect(response).to have_http_status(:success)

    expect(Portail::HubAPI::Deliveries).to receive(:list)
      # Le reste du hash est éprouvé dans le spec de l'étape FetchList.
      .with(hash_including(data_stream_codes: ["DECES"]))
      .and_return(build(:portail_delivery_list))
    get teledossiers_path

    expect(response).to have_http_status(:success)
  end

  it "closes the access of a deleted agent at the next request and refuses its next sign-in" do
    expect_empty_deliveries
    agent = sign_in_member
    get teledossiers_path
    expect(response).to have_http_status(:success)

    delete "/api/internal/v1/agents/#{agent.id}", headers: bearer(admin_portal), as: :json
    expect(response).to have_http_status(:no_content)

    get teledossiers_path
    expect(response).to redirect_to(root_path)

    mock_proconnect(sub: agent.provider_sub, email: agent.email)
    proconnect_callback
    expect(response).to redirect_to(denied_path)
    expect(ProviderSession.denied.last.denial_reason).to eq("unknown_agent")
  end

  # L'API ne touche pas aux sessions : c'est le portail qui ferme, à la requête suivante, celle dont
  # l'adresse n'est plus celle de l'agent.
  it "closes the session when the email changes, refuses the old address and accepts the new one" do
    expect_empty_deliveries
    agent = sign_in_member
    old_email = agent.email
    get teledossiers_path
    expect(response).to have_http_status(:success)

    patch "/api/internal/v1/agents/#{agent.id}", params: {agent: {email: "nouvelle.adresse@ville.fr"}}, headers: bearer(admin_portal), as: :json
    expect(response).to have_http_status(:success)
    expect(ProviderSession.granted.sole.email).to eq(old_email)

    get teledossiers_path
    expect(response).to redirect_to(root_path)
    expect(ProviderSession.granted).to be_empty

    mock_proconnect(sub: agent.provider_sub, email: old_email)
    proconnect_callback
    expect(response).to redirect_to(denied_path)
    expect(ProviderSession.denied.last.denial_reason).to eq("email_mismatch")

    mock_proconnect(sub: agent.provider_sub, email: "nouvelle.adresse@ville.fr")
    proconnect_callback
    follow_redirect!
    follow_redirect!
    expect(request.path).to eq(teledossiers_path)
    expect(response).to have_http_status(:success)
  end

  # La course : une connexion a résolu l'agent par son ancienne adresse quand le changement se valide, et
  # ouvre sa session après lui, avec l'ancienne adresse. Elle tombe dès la requête suivante.
  it "closes at the next request a session opened with the old email by a sign-in under way during the change" do
    agent = create(:agent, provider_sub: "sub-membre")
    old_email = agent.email
    expect(Portail::Sessions::Create::FindMembership).to receive(:call!).and_wrap_original do |original, context|
      original.call(context)
      form = API::Internal::V1::AgentUpdateForm.new(agent: Agent.find(agent.id), email: "nouvelle.adresse@ville.fr")
      API::Internal::V1::Agents::Update.call!(form:, api_client: admin_portal, request_id: "requete-concurrente")
    end
    sign_in_via_proconnect(agent:)
    create(:data_stream_access, membership: Membership.find_by!(agent:), data_stream_code: "CERTDC")
    expect(agent.reload.email).to eq("nouvelle.adresse@ville.fr")
    expect(ProviderSession.granted.sole.email).to eq(old_email)

    get teledossiers_path

    expect(response).to redirect_to(root_path)
    expect(ProviderSession.count).to eq(0)
  end
end
