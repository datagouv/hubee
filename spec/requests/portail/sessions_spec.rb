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
      it "refuses access, creates nothing, and explains the situation" do
        mock_proconnect(sub: "sub-unknown")

        expect {
          get "/auth/proconnect/callback"
        }.not_to change(Agent, :count)

        expect(response).to redirect_to(denied_path)
        follow_redirect!
        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("Votre compte n'est pas reconnu")
        expect(Capybara.string(response.body)).to have_text("support@hubee.numerique.gouv.fr")
      end

      # Sa session ProConnect reste ouverte : sans cette issue, recliquer sur le bouton
      # le réauthentifierait à l'identique et il resterait bloqué sur cette page.
      it "shows the address used and offers to retry with another account" do
        mock_proconnect(sub: "sub-unknown", email: "alex@example.gouv.fr")

        get "/auth/proconnect/callback"
        follow_redirect!

        page = Capybara.string(response.body)
        expect(page).to have_text("alex@example.gouv.fr")
        expect(page).to have_button("Essayer avec un autre compte")
        expect(page).to have_css("form[action='/logout'][data-turbo='false']")
      end
    end

    # Le niveau est contrôlé avant même de chercher l'agent : au niveau 0, le lien
    # organisationnel est déclaratif, quel que soit le compte présenté.
    context "when the authentication level does not certify the organisation" do
      it "refuses access and explains why" do
        mock_proconnect(sub: "sub-unknown", acr: "eidas0")

        get "/auth/proconnect/callback"
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("Votre rattachement n'a pas été vérifié")
      end
    end

    context "when the agent is attached to another organisation" do
      # Sans nommer l'organisation, l'agent ne peut pas savoir laquelle il a présentée —
      # c'est le seul refus qu'il ne pouvait pas diagnostiquer seul.
      it "refuses access and names the organisation he came in with" do
        agent = create(:agent, provider_sub: "sub-known")
        create(:membership, agent:, organization_link: create(:organization_link))
        mock_proconnect(sub: "sub-known", email: agent.email, organization_label: "Commune de Clamart")

        get "/auth/proconnect/callback"
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("Commune de Clamart")
      end

      # ProConnect ne garantit pas le libellé : le message doit rester lisible sans lui.
      it "falls back to a generic wording when ProConnect sent no label" do
        agent = create(:agent, provider_sub: "sub-known")
        create(:membership, agent:, organization_link: create(:organization_link))
        mock_proconnect(sub: "sub-known", email: agent.email, organization_label: nil)

        get "/auth/proconnect/callback"
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("l'organisation que vous avez choisie")
      end
    end

    context "when the sub is known but the email does not match" do
      it "refuses access and explains why" do
        create(:agent, provider_sub: "sub-known", email: "enrolled@example.gouv.fr")
        mock_proconnect(sub: "sub-known", email: "other@example.gouv.fr")

        get "/auth/proconnect/callback"
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("ne correspond pas à votre compte")
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

  # Un refus est une authentification ProConnect sans rattachement : elle est consignée
  # comme telle, et le cookie cesse de porter un jeton sur ce chemin aussi.
  describe "recording a refusal" do
    it "keeps the refused authentication as a record" do
      mock_proconnect(sub: "sub-unknown", email: "alex@example.gouv.fr")

      expect { get "/auth/proconnect/callback" }.to change(ProviderSession.denied, :count).by(1)

      expect(ProviderSession.denied.last).to have_attributes(
        denial_reason: "unknown_agent", email: "alex@example.gouv.fr", membership: nil
      )
    end

    # Un refus pour niveau insuffisant qui ne dirait pas quel niveau a été atteint ne
    # consignerait pas son propre diagnostic.
    it "records how the agent authenticated, and at which level" do
      mock_proconnect(sub: "sub-unknown", amr: ["pwd"], acr: "eidas0")

      get "/auth/proconnect/callback"

      expect(ProviderSession.denied.last).to have_attributes(
        denial_reason: "insufficient_authentication_level", amr: ["pwd"], acr: "eidas0"
      )
    end

    # Abandon implicite : l'agent ne clique pas sur « essayer avec un autre compte », il
    # retente simplement. La tentative précédente n'a plus lieu d'être conservée.
    it "discards the previous attempt when a new one begins" do
      OmniAuth.config.mock_auth[:proconnect] = OmniAuth::AuthHash.new(
        provider: "proconnect", uid: "sub-unknown",
        info: {email: "alex@example.gouv.fr"}, credentials: {id_token: "test-id-token"},
        extra: {nonce: "test-nonce", raw_info: {"siret" => "99999999911111"}}
      )
      expect(Portail::ProConnect::TokenVerifier).to receive(:call).twice
        .and_return(sub: "sub-unknown", amr: ["pwd"], acr: "eidas1")
      get "/auth/proconnect/callback"

      expect { get "/auth/proconnect/callback" }.not_to change(ProviderSession, :count)
    end

    # Sans adresse, la page de refus n'aurait rien à montrer. La page d'échec vaut mieux
    # qu'un 500 sur le chemin d'authentification.
    it "falls back to the failure page when ProConnect sent no address" do
      mock_proconnect(sub: "sub-unknown", email: nil)

      get "/auth/proconnect/callback"

      expect(response).to redirect_to(auth_failure_path)
    end
  end

  # Le callback est joignable sans authentification et déclenche deux appels sortants vers
  # ProConnect. Sans limite, n'importe qui nous transforme en amplificateur à ses frais.
  describe "flooding the callback" do
    it "turns away a caller who hammers it" do
      OmniAuth.config.mock_auth[:proconnect] = OmniAuth::AuthHash.new(
        provider: "proconnect", uid: "x",
        info: {email: "a@b.fr"}, credentials: {id_token: "t"}, extra: {nonce: "n"}
      )
      # Un jeton rejeté : chaque passage coûte le minimum et n'écrit rien.
      expect(Portail::ProConnect::TokenVerifier).to receive(:call).at_least(:once)
        .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)

      10.times { get "/auth/proconnect/callback" }
      get "/auth/proconnect/callback"

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  # Le callback porte un code à usage unique : rendre le refus sur son URL la rendait
  # irrechargeable. Le motif vit en session, la page a sa propre adresse.
  describe "GET /connexion/refusee" do
    it "still explains the refusal when the page is reloaded" do
      mock_proconnect(sub: "sub-unknown")
      get "/auth/proconnect/callback"

      get denied_path
      get denied_path

      expect(response).to have_http_status(:forbidden)
      expect(Capybara.string(response.body)).to have_text("Votre compte n'est pas reconnu")
    end

    it "sends the visitor home when no refusal is pending" do
      get denied_path

      expect(response).to redirect_to(root_path)
    end

    # Un motif renommé depuis que l'agent a été refusé : mieux vaut l'accueil qu'une page
    # qui tombe sur une traduction manquante.
    it "sends the visitor home when the reason no longer has a message" do
      mock_proconnect(sub: "sub-unknown")
      get "/auth/proconnect/callback"
      ProviderSession.denied.last.update!(denial_reason: "motif_disparu")

      get denied_path

      expect(response).to redirect_to(root_path)
    end

    # Abandonner une tentative doit l'effacer : sans ça, son jeton survivrait un quart
    # d'heure alors que l'agent a explicitement tourné la page.
    it "erases the refused attempt when the agent gives up on it" do
      expect(Portail::ProConnect::LogoutUrlBuilder).to receive(:call)
        .with(id_token: "test-id-token")
        .and_return("https://proconnect.test/session/end?id_token_hint=test-id-token")
      mock_proconnect(sub: "sub-unknown")
      get "/auth/proconnect/callback"

      expect { delete "/logout" }.to change(ProviderSession, :count).by(-1)

      expect(response).to redirect_to("https://proconnect.test/session/end?id_token_hint=test-id-token")
    end
  end

  # Deux onglets, une seule session : celui qui agit en second présente le jeton d'avant
  # le renouvellement. La requête doit être refusée sans exposer d'erreur brute.
  describe "a page whose CSRF token has expired" do
    it "reloads the home page instead of failing" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)
      ActionController::Base.allow_forgery_protection = true

      delete "/logout", params: {authenticity_token: "périmé"}

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(Capybara.string(response.body)).to have_text("Cette page n'était plus à jour")
    ensure
      ActionController::Base.allow_forgery_protection = false
    end
  end

  # Une page ressortie du cache porterait un jeton CSRF périmé, et le bouton ProConnect
  # échouerait en InvalidAuthenticityToken au clic suivant.
  describe "browser caching" do
    it "forbids storing portal pages" do
      get root_path

      expect(response).to have_http_status(:success)
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  describe "GET /auth/failure" do
    it "renders a comprehensible failure page without a session" do
      get "/auth/failure"

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to include("La connexion a échoué")
      # Réessayer ne changera rien à une panne du fournisseur : sans le support, l'agent
      # n'a aucun recours.
      expect(response.body).to include("support@hubee.numerique.gouv.fr")
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

    it "requires a new authentication after too long without activity" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)

      travel(31.minutes) { get root_path }

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_button("S'identifier avec ProConnect")
      # Sans message, l'agent retrouve le bouton de connexion sans savoir pourquoi.
      expect(Capybara.string(response.body)).to have_text("Votre session a expiré")
    end

    # Sans borne absolue, une session entretenue par de l'activité durerait indéfiniment.
    # Les requêtes espacées de moins de 30 minutes empêchent le délai d'inactivité de se
    # déclencher : seule la borne absolue peut fermer celle-ci.
    it "requires a new authentication once the absolute lifetime is reached, even while active" do
      agent = create(:agent, provider_sub: "sub-known")
      opened_at = Time.current
      sign_in_via_proconnect(agent:)

      24.times { |i| travel_to(opened_at + ((i + 1) * 29).minutes) { get root_path } }
      travel_to(opened_at + 12.hours + 1.minute) { get root_path }

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_button("S'identifier avec ProConnect")
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

    # La session locale est détruite avant tout appel sortant : une panne de ProConnect ne
    # doit jamais retenir un agent connecté au portail.
    it "still signs the agent out of the portal when ProConnect is unreachable" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)
      expect(Portail::ProConnect::LogoutUrlBuilder).to receive(:call)
        .and_raise(Portail::ProConnect::Discovery::Unavailable)

      delete "/logout"

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(Capybara.string(response.body)).to have_button("S'identifier avec ProConnect")
    end
  end

  # Une panne du fournisseur n'est pas une décision sur l'agent : elle ne doit pas
  # atterrir sur la page de refus, qui parlerait à tort de son compte.
  describe "when ProConnect is unreachable during the callback" do
    it "redirects to the failure page without opening a session" do
      OmniAuth.config.mock_auth[:proconnect] = OmniAuth::AuthHash.new(
        provider: "proconnect", uid: "x",
        info: {email: "a@b.fr"}, credentials: {id_token: "t"}, extra: {nonce: "n"}
      )
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_raise(Portail::ProConnect::Discovery::Unavailable)

      get "/auth/proconnect/callback"

      expect(response).to redirect_to(auth_failure_path)
    end
  end
end
