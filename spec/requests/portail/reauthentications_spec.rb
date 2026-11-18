# frozen_string_literal: true

require "rails_helper"

# La réauthentification d'un agent déjà connecté : une déconnexion ProConnect, puis une connexion
# relancée par le portail. ProConnect est simulé à sa frontière, Portail::ProConnect::Client.
RSpec.describe "Portail::Reauthentications", type: :request do
  let(:subscription_id) { "550e8400-e29b-41d4-a716-446655440000" }
  let(:purpose) { Portail::Access::Reauthentication.purpose(:credentials, subscription_id) }
  let(:return_to) { "/abonnements/#{subscription_id}" }

  def start_reauthentication(return_to: self.return_to)
    allow(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
      .and_return("https://proconnect.test/api/v2/session/end?id_token_hint=x")
    post reauthentication_path, params: {purpose:, return_to:}
  end

  def proconnect_authorization
    Portail::ProConnect::Client::Authorization.new(url: "https://proconnect.test/api/v2/authorize",
      state: ProConnectTestHelper::STATE, nonce: ProConnectTestHelper::NONCE)
  end

  describe "POST /connexion/reauthentification" do
    it "logs the agent out of ProConnect, towards the reauthentication address" do
      sign_in_local_administrator
      id_token = ProviderSession.granted.sole.provider_id_token

      expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url).with(id_token:)
        .and_return("https://proconnect.test/api/v2/session/end?id_token_hint=x")
      post reauthentication_path, params: {purpose:, return_to:}

      expect(response).to redirect_to("https://proconnect.test/api/v2/session/end?id_token_hint=x")
    end

    it "remembers the purpose and the way back" do
      freeze_time
      sign_in_local_administrator

      start_reauthentication

      expect(session[:reauthentication]).to eq("purpose" => purpose, "return_to" => return_to,
        "provider_session_id" => ProviderSession.granted.sole.id, "started_at" => Time.current.to_i)
    end

    it "ignores a way back to another host" do
      sign_in_local_administrator

      %w[//evil.example https://evil.example evil.example].each do |forged|
        start_reauthentication(return_to: forged)

        expect(session[:reauthentication]["return_to"]).to eq("/")
      end
    end

    it "turns a signed-out visitor away" do
      post reauthentication_path, params: {purpose:, return_to:}

      expect(response).to redirect_to(root_path)
      expect(session[:reauthentication]).to be_nil
    end

    # Rien n'a été fermé : l'agent reste connecté et retrouve sa page.
    it "brings the agent back when ProConnect cannot be reached" do
      sign_in_local_administrator
      allow(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
        .and_raise(Portail::ProConnect::Client::Unavailable)

      post reauthentication_path, params: {purpose:, return_to:}

      expect(response).to redirect_to(return_to)
      expect(flash[:alert]).to eq("La vérification de votre identité n'a pas abouti. Réessayez.")
      expect(session[:reauthentication]).to be_nil
    end
  end

  describe "GET /connexion/proconnect/reauthentification" do
    it "departs for ProConnect on the way back from logout, with hints" do
      agent = sign_in_local_administrator
      start_reauthentication

      expect(Portail::ProConnect::Client).to receive(:authorization)
        .with(step_up: true, login_hint: agent.email, siret_hint: ProConnectTestHelper::TEST_SIRET)
        .and_return(proconnect_authorization)
      get reauthentication_resume_path

      expect(response).to redirect_to("https://proconnect.test/api/v2/authorize")
      expect(session[:proconnect_state]).to eq(ProConnectTestHelper::STATE)
      expect(session[:proconnect_nonce]).to eq(ProConnectTestHelper::NONCE)
    end

    it "does not demand a second factor from a member who needs none" do
      sign_in_member
      start_reauthentication

      expect(Portail::ProConnect::Client).to receive(:authorization)
        .with(hash_including(step_up: false)).and_return(proconnect_authorization)
      get reauthentication_resume_path

      expect(response).to redirect_to("https://proconnect.test/api/v2/authorize")
    end

    it "goes home on a logout return with no reauthentication pending" do
      sign_in_local_administrator

      expect(Portail::ProConnect::Client).not_to receive(:authorization)
      get reauthentication_resume_path

      expect(response).to redirect_to(root_path)
    end

    it "goes home on a logout return whose reauthentication is older than 10 minutes" do
      sign_in_local_administrator
      start_reauthentication
      ProviderSession.granted.sole.touch
      travel 11.minutes
      # La session elle-même reste ouverte : seule l'attente du parcours a expiré.
      ProviderSession.granted.sole.touch

      expect(Portail::ProConnect::Client).not_to receive(:authorization)
      get reauthentication_resume_path

      expect(response).to redirect_to(root_path)
      expect(session[:reauthentication]).to be_nil
    end
  end
end
