# frozen_string_literal: true

require "rails_helper"

# La réauthentification d'un agent déjà connecté : une déconnexion ProConnect, puis une connexion
# relancée par le portail. ProConnect est simulé à sa frontière, Portail::ProConnect::Client.
#
# Toutes les réponses de ce parcours sont des redirections : `redirect_to` vérifie déjà le statut 3xx,
# `have_http_status` n'y ajouterait rien.
RSpec.describe "Portail::Reauthentications", type: :request do
  let(:subscription_id) { "550e8400-e29b-41d4-a716-446655440000" }
  let(:purpose) { Portail::Access::Reauthentication.purpose(:credentials, subscription_id) }
  let(:return_to) { "/abonnements/#{subscription_id}" }

  def start_reauthentication(return_to: self.return_to)
    expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
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
      expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
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
      # Seule la connexion lancée ici conclura la réauthentification.
      expect(session[:reauthentication]["state"]).to eq(ProConnectTestHelper::STATE)
    end

    it "does not demand a second factor from a member who needs none" do
      agent = sign_in_member
      start_reauthentication

      expect(Portail::ProConnect::Client).to receive(:authorization)
        .with(step_up: false, login_hint: agent.email, siret_hint: ProConnectTestHelper::TEST_SIRET)
        .and_return(proconnect_authorization)
      get reauthentication_resume_path

      expect(response).to redirect_to("https://proconnect.test/api/v2/authorize")
    end

    it "goes home on a logout return with no reauthentication pending" do
      sign_in_local_administrator

      expect(Portail::ProConnect::Client).not_to receive(:authorization)
      get reauthentication_resume_path

      expect(response).to redirect_to(root_path)
    end

    # Rien n'a été fermé côté portail : l'agent retrouve sa page, le parcours est abandonné.
    it "brings the agent back to the page when ProConnect cannot be reached on the way back from logout" do
      sign_in_local_administrator
      start_reauthentication
      expect(Portail::ProConnect::Client).to receive(:authorization).and_raise(Portail::ProConnect::Client::Unavailable)

      get reauthentication_resume_path

      expect(response).to redirect_to(return_to)
      expect(flash[:alert]).to eq("La vérification de votre identité n'a pas abouti. Réessayez.")
      expect(session[:reauthentication]).to be_nil
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

  # Le décor par défaut est le membre habilité : le cas standard du portail, sans second facteur exigé.
  # Les exemples qui dépendent du second facteur passent l'agent administrateur local eux-mêmes.
  describe "GET /connexion/proconnect/retour during a reauthentication" do
    let(:agent) { Agent.find_by!(provider_sub: "sub-membre") }

    before { sign_in_member }

    def granted_session = ProviderSession.granted.sole

    def promote_to_local_administrator = Membership.find_by!(agent:).update!(role: "local_administrator")

    it "returns to the page with a proof, and keeps the session" do
      freeze_time
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])

      reauthenticate(purpose:, return_to:)

      expect(response).to redirect_to(return_to)
      expect(granted_session).to have_attributes(id: session[:provider_session_id], reauthenticated_for: purpose,
        reauthenticated_at: Time.current, provider_id_token: "test-id-token")
      expect(AccessDecision.last).to have_attributes(outcome: "granted", kind: "reauthentication")
      expect(session[:reauthentication]).to be_nil
    end

    # Le scénario du collègue sur le poste : il ne peut entrer qu'avec son propre compte.
    it "closes the session when another agent comes back" do
      colleague = create(:agent, provider_sub: "sub-collegue", email: "collegue@example.gouv.fr")
      create(:membership, agent: colleague, organization_link: OrganizationLink.sole)
      mock_proconnect(sub: colleague.provider_sub, email: colleague.email, acr: "eidas1-mfa")

      reauthenticate(purpose:, return_to:)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Le compte utilisé pour vérifier votre identité n'est pas celui de votre " \
        "session : par sécurité, votre session a été fermée.")
      expect(ProviderSession.granted).to be_empty
      expect(AccessDecision.last).to have_attributes(outcome: "denied", kind: "reauthentication",
        reason: "reauthentication_mismatch", email: "collegue@example.gouv.fr", provider_sub: "sub-collegue",
        agent_id: agent.id)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(Capybara.string(response.body)).to have_button("S'identifier avec ProConnect")
    end

    # Le contournement de la déconnexion : la connexion relancée réutilise la session ProConnect de
    # l'agent, sans aucune saisie. Le même `sid` en témoigne.
    it "closes the session when ProConnect reused the session of the sign-in" do
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1-mfa", sid: granted_session.provider_sid)

      reauthenticate(purpose:, return_to:)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("Votre identité n'a pas pu être vérifiée : la déconnexion de ProConnect " \
        "n'a pas eu lieu. Par sécurité, votre session a été fermée.")
      expect(ProviderSession.granted).to be_empty
      expect(AccessDecision.last).to have_attributes(outcome: "denied", kind: "reauthentication",
        reason: "reauthentication_without_logout", agent_id: agent.id)
    end

    it "closes the session when someone unknown to the portal comes back" do
      mock_proconnect(sub: "sub-inconnu", email: "inconnu@example.gouv.fr", acr: "eidas1-mfa")

      reauthenticate(purpose:, return_to:)

      expect(response).to redirect_to(root_path)
      expect(ProviderSession.granted).to be_empty
      expect(AccessDecision.last.reason).to eq("reauthentication_mismatch")
    end

    it "closes the session when the agent comes back under another organisation" do
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1-mfa", siret: "11111111100000")

      reauthenticate(purpose:, return_to:)

      expect(response).to redirect_to(root_path)
      expect(ProviderSession.granted).to be_empty
      expect(AccessDecision.last.reason).to eq("reauthentication_mismatch")
    end

    it "keeps the session when ProConnect returns an error" do
      reauthenticate(purpose:, return_to:, params: {error: "access_denied"})

      expect(response).to redirect_to(return_to)
      expect(flash[:alert]).to eq("La vérification de votre identité n'a pas abouti. Réessayez.")
      expect(granted_session).to have_attributes(id: session[:provider_session_id], reauthenticated_at: nil)
      expect(AccessDecision.last).to have_attributes(outcome: "denied", kind: "reauthentication",
        reason: "reauthentication_aborted", agent_id: agent.id)
    end

    # Un retour qui ne porte pas le `state` de la connexion lancée au retour de déconnexion n'est
    # pas celui de la réauthentification : il suit le parcours ordinaire, qui le refuse.
    it "keeps the session and grants nothing on an invalid state" do
      reauthenticate(purpose:, return_to:, params: {state: "forged-state"})

      expect(response).to redirect_to(auth_failure_path)
      expect(granted_session).to have_attributes(id: session[:provider_session_id], reauthenticated_at: nil)
    end

    # Le chemin le plus court pour qui voudrait éviter la déconnexion : lancer une connexion
    # ordinaire pendant qu'une réauthentification attend. Elle ne prouve rien.
    it "does not take an authorization it did not launch as a reauthentication" do
      expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
        .and_return("https://proconnect.test/api/v2/session/end")
      post reauthentication_path, params: {purpose:, return_to:}
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1-mfa")

      proconnect_callback

      expect(response).to redirect_to(root_path)
      expect(AccessDecision.last).to have_attributes(outcome: "granted", kind: "sign_in")
      expect(ProviderSession.granted.sole.reauthenticated_at).to be_nil
      expect(AccessDecision.where(kind: "reauthentication")).to be_empty
    end

    it "keeps the session when the second factor is missing" do
      promote_to_local_administrator
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])

      reauthenticate(purpose:, return_to:)

      expect(response).to redirect_to(return_to)
      expect(flash[:alert]).to eq("La vérification de votre identité n'a pas abouti. Réessayez.")
      expect(granted_session).to have_attributes(reauthenticated_at: nil, provider_id_token: "test-id-token")
      expect(AccessDecision.last).to have_attributes(kind: "reauthentication", reason: "second_factor_required")
      # La session garde son second facteur : l'administrateur local n'est pas éjecté.
      get "/"
      expect(response).not_to redirect_to(step_up_path)
    end

    it "keeps the session when ProConnect cannot be reached on the way back" do
      expect(Portail::ProConnect::Client).to receive(:exchange).and_raise(Portail::ProConnect::Client::Unavailable)

      expect { reauthenticate(purpose:, return_to:) }.not_to change(AccessDecision, :count)

      expect(response).to redirect_to(return_to)
      expect(granted_session.reauthenticated_at).to be_nil
    end

    # Un parcours oublié ne doit pas capter une connexion ordinaire faite plus tard.
    it "signs in as usual when an abandoned reauthentication has expired" do
      expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
        .and_return("https://proconnect.test/api/v2/session/end")
      post reauthentication_path, params: {purpose:, return_to:}
      travel 11.minutes
      granted_session.touch
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1-mfa")

      proconnect_callback

      expect(response).to redirect_to(root_path)
      expect(AccessDecision.last).to have_attributes(outcome: "granted", kind: "sign_in")
      expect(granted_session.reauthenticated_at).to be_nil
    end
  end
end
