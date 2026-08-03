# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Sessions", type: :request do
  describe "GET /auth/proconnect/callback" do
    context "when the agent is known to the portal" do
      it "opens a session and redirects to the dashboard" do
        agent = create(:agent, provider_sub: "sub-known")

        sign_in_via_proconnect(agent: agent)

        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Connecté en tant que")
      end
    end

    context "when the agent is authenticated but unknown to the portal" do
      let(:switch_account_url) { "https://proconnect.test/session/end?id_token_hint=test-id-token" }

      # La page de refus construit l'URL de déconnexion ProConnect : les deux exemples
      # passent donc par LogoutUrlBuilder. On le court-circuite ici — la découverte OIDC
      # qu'il déclenche est testée en propre dans discovery_spec.rb.
      before do
        expect(Portail::ProConnect::LogoutUrlBuilder).to receive(:call)
          .with(id_token: "test-id-token")
          .and_return(switch_account_url)
      end

      it "refuses access, creates nothing, and explains the situation" do
        mock_proconnect(sub: "sub-unknown")

        expect {
          get "/auth/proconnect/callback"
        }.not_to change(Agent, :count)

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("votre compte n'est pas reconnu")
        expect(Capybara.string(response.body)).to have_text("support@hubee.numerique.gouv.fr")
      end

      # Sa session ProConnect reste ouverte : sans ce lien, recliquer sur le bouton le
      # réauthentifierait à l'identique et il resterait bloqué sur cette page.
      it "shows the address used and offers to retry with another account" do
        mock_proconnect(sub: "sub-unknown", email: "alex@example.gouv.fr")

        get "/auth/proconnect/callback"

        page = Capybara.string(response.body)
        expect(page).to have_text("alex@example.gouv.fr")
        expect(page).to have_link("Essayer avec un autre compte", href: switch_account_url)
      end
    end

    # Le niveau est contrôlé avant même de chercher l'agent : au niveau 0, le lien
    # organisationnel est déclaratif, quel que soit le compte présenté.
    context "when the authentication level does not certify the organisation" do
      it "refuses access and explains why" do
        expect(Portail::ProConnect::LogoutUrlBuilder).to receive(:call)
          .and_return("https://proconnect.test/session/end?id_token_hint=test-id-token")
        mock_proconnect(sub: "sub-unknown", acr: "eidas0")

        get "/auth/proconnect/callback"

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("ne permet pas d'accéder au portail")
      end
    end

    context "when token verification fails" do
      it "redirects to the failure page without opening a session" do
        OmniAuth.config.mock_auth[:proconnect] = OmniAuth::AuthHash.new(
          provider: "proconnect", uid: "x",
          info: {email: "a@b.fr"}, credentials: {id_token: "t"}, extra: {nonce: "n"}
        )
        expect(Portail::ProConnect::TokenVerifier).to receive(:call)
          .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)

        get "/auth/proconnect/callback"

        expect(response).to redirect_to(auth_failure_path)
      end
    end
  end

  describe "GET /auth/failure" do
    it "renders a comprehensible failure page without a session" do
      get "/auth/failure"

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("La connexion a échoué")
    end
  end

  describe "the signed-in dashboard" do
    # La déconnexion redirige vers ProConnect (cross-origin). Turbo ne sait pas rendre
    # une telle redirection et laisse la page inchangée : la session est bien détruite
    # côté serveur, mais le bouton de connexion ne réapparaît pas. Le formulaire doit
    # donc sortir de Turbo, comme celui de connexion.
    it "renders a logout form that bypasses Turbo" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)

      get root_path

      expect(Capybara.string(response.body)).to have_css("form[action='/logout'][data-turbo='false']")
    end

    it "closes access on the next request when the membership is revoked" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)

      agent.memberships.destroy_all
      get root_path

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_button("S'identifier avec ProConnect")
    end
  end

  describe "DELETE /logout" do
    it "clears the session and redirects to the ProConnect end_session URL" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)
      expect(Portail::ProConnect::LogoutUrlBuilder).to receive(:call)
        .with(id_token: "test-id-token")
        .and_return("https://proconnect.test/session/end?id_token_hint=test-id-token")

      delete "/logout"

      expect(response).to redirect_to("https://proconnect.test/session/end?id_token_hint=test-id-token")
    end
  end
end
