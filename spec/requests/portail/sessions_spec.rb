# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Sessions", type: :request do
  describe "GET /connexion/proconnect/retour" do
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
          proconnect_callback
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

        proconnect_callback
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

        proconnect_callback
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

        proconnect_callback
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("Commune de Clamart")
      end

      # ProConnect ne garantit pas le libellé : le message doit rester lisible sans lui.
      it "falls back to a generic wording when ProConnect sent no label" do
        agent = create(:agent, provider_sub: "sub-known")
        create(:membership, agent:, organization_link: create(:organization_link))
        mock_proconnect(sub: "sub-known", email: agent.email, organization_label: nil)

        proconnect_callback
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("l'organisation que vous avez choisie")
      end
    end

    context "when the sub is known but the email does not match" do
      it "refuses access and explains why" do
        create(:agent, provider_sub: "sub-known", email: "enrolled@example.gouv.fr")
        mock_proconnect(sub: "sub-known", email: "other@example.gouv.fr")

        proconnect_callback
        follow_redirect!

        expect(response).to have_http_status(:forbidden)
        expect(Capybara.string(response.body)).to have_text("ne correspond pas à votre compte")
      end
    end

    # ProConnect renvoie ses refus en paramètre. Les lire d'abord : enchaîner l'échange du
    # code échouerait plus loin sous un motif trompeur — les journaux parleraient de
    # décodage JWT là où il faudrait lire « accès refusé ».
    context "when ProConnect refuses in the callback parameters" do
      it "goes to the failure page without trying to exchange anything" do
        mock_proconnect_transport
        expect(Portail::ProConnect::Client).not_to receive(:exchange)
        depart_for_proconnect

        get "/connexion/proconnect/retour",
          params: {error: "access_denied", state: ProConnectTestHelper::STATE}

        expect(response).to redirect_to(auth_failure_path)
        expect(ProviderSession.count).to eq(0)
      end
    end

    # Le `state` lie la réponse à la demande qu'on a émise. Sans ce contrôle, un callback
    # fabriqué par un tiers ouvrirait une session dans le navigateur de l'agent.
    context "when the state does not match the one we sent" do
      it "refuses the callback without exchanging anything" do
        mock_proconnect_transport
        expect(Portail::ProConnect::Client).not_to receive(:exchange)
        depart_for_proconnect

        get "/connexion/proconnect/retour", params: {code: "test-code", state: "forged"}

        expect(response).to redirect_to(auth_failure_path)
        expect(ProviderSession.count).to eq(0)
      end

      # Un `state` ne vaut que pour un aller-retour : le rejouer doit échouer, sinon un
      # callback intercepté resterait utilisable.
      it "refuses a second callback carrying the same state" do
        agent = create(:agent, provider_sub: "sub-known")
        sign_in_via_proconnect(agent:)

        get "/connexion/proconnect/retour",
          params: {code: "test-code", state: ProConnectTestHelper::STATE}

        expect(response).to redirect_to(auth_failure_path)
      end
    end

    context "when token verification fails" do
      it "redirects to the failure page without opening a session" do
        mock_proconnect_transport(email: "a@b.fr")
        expect(Portail::ProConnect::TokenVerifier).to receive(:call)
          .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)

        proconnect_callback

        expect(response).to redirect_to(auth_failure_path)
      end
    end
  end

  # Un refus est une authentification ProConnect sans rattachement : elle est consignée
  # comme telle, et le cookie cesse de porter un jeton sur ce chemin aussi.
  describe "recording a refusal" do
    it "keeps the refused authentication as a record" do
      mock_proconnect(sub: "sub-unknown", email: "alex@example.gouv.fr")

      expect { proconnect_callback }.to change(ProviderSession.denied, :count).by(1)

      expect(ProviderSession.denied.last).to have_attributes(
        denial_reason: "unknown_agent", email: "alex@example.gouv.fr", membership: nil
      )
    end

    # Un refus pour niveau insuffisant qui ne dirait pas quel niveau a été atteint ne
    # consignerait pas son propre diagnostic.
    it "records how the agent authenticated, and at which level" do
      mock_proconnect(sub: "sub-unknown", amr: ["pwd"], acr: "eidas0")

      proconnect_callback

      expect(ProviderSession.denied.last).to have_attributes(
        denial_reason: "insufficient_authentication_level", amr: ["pwd"], acr: "eidas0"
      )
    end

    # Abandon implicite : l'agent ne clique pas sur « essayer avec un autre compte », il
    # retente simplement. La tentative précédente n'a plus lieu d'être conservée.
    it "discards the previous attempt when a new one begins" do
      mock_proconnect_transport(email: "alex@example.gouv.fr")
      expect(Portail::ProConnect::TokenVerifier).to receive(:call).twice
        .and_return(sub: "sub-unknown", amr: ["pwd"], acr: "eidas1")
      proconnect_callback

      expect { proconnect_callback }.not_to change(ProviderSession, :count)
    end

    # Sans adresse, la page de refus n'aurait rien à montrer. La page d'échec vaut mieux
    # qu'un 500 sur le chemin d'authentification.
    it "falls back to the failure page when ProConnect sent no address" do
      mock_proconnect(sub: "sub-unknown", email: nil)

      proconnect_callback

      expect(response).to redirect_to(auth_failure_path)
    end
  end

  # Le callback est joignable sans authentification et déclenche deux appels sortants vers
  # ProConnect. Sans limite, n'importe qui nous transforme en amplificateur à ses frais.
  describe "flooding the callback" do
    it "turns away a caller who hammers it" do
      mock_proconnect_transport(email: "a@b.fr")
      # Un jeton rejeté : chaque passage coûte le minimum et n'écrit rien.
      expect(Portail::ProConnect::TokenVerifier).to receive(:call).at_least(:once)
        .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)

      10.times { proconnect_callback }
      proconnect_callback

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  # Le callback porte un code à usage unique : rendre le refus sur son URL la rendait
  # irrechargeable. Le motif vit en session, la page a sa propre adresse.
  describe "GET /connexion/refusee" do
    it "still explains the refusal when the page is reloaded" do
      mock_proconnect(sub: "sub-unknown")
      proconnect_callback

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
      proconnect_callback
      ProviderSession.denied.last.update!(denial_reason: "motif_disparu")

      get denied_path

      expect(response).to redirect_to(root_path)
    end

    # Abandonner une tentative doit l'effacer : sans ça, son jeton survivrait un quart
    # d'heure alors que l'agent a explicitement tourné la page.
    it "erases the refused attempt when the agent gives up on it" do
      expect(Portail::ProConnect::Client).to receive(:logout_url)
        .with(hash_including(id_token: "test-id-token"))
        .and_return("https://proconnect.test/session/end?id_token_hint=test-id-token")
      mock_proconnect(sub: "sub-unknown")
      proconnect_callback

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

  describe "GET /connexion/echec" do
    it "renders a comprehensible failure page without a session" do
      get "/connexion/echec"

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

      # follow_redirect! n'est pas décoratif : c'est le seul moyen de vérifier que le
      # message franchit la redirection. Posé en flash.now, il serait perdu ici.
      travel(31.minutes) { get root_path }
      follow_redirect!

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
      travel_to(opened_at + 12.hours + 1.minute) do
        get root_path
        follow_redirect!
      end

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
      expect(Portail::ProConnect::Client).to receive(:logout_url)
        .with(hash_including(id_token: "test-id-token"))
        .and_return("https://proconnect.test/session/end?id_token_hint=test-id-token")

      delete "/logout"

      expect(response).to redirect_to("https://proconnect.test/session/end?id_token_hint=test-id-token")
    end

    # La session locale est détruite avant tout appel sortant : une panne de ProConnect ne
    # doit jamais retenir un agent connecté au portail.
    it "still signs the agent out of the portal when ProConnect is unreachable" do
      agent = create(:agent, provider_sub: "sub-known")
      sign_in_via_proconnect(agent:)
      expect(Portail::ProConnect::Client).to receive(:logout_url)
        .and_raise(Portail::ProConnect::Client::Unavailable)

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
      mock_proconnect_transport(email: "a@b.fr")
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_raise(Portail::ProConnect::Client::Unavailable)

      proconnect_callback

      expect(response).to redirect_to(auth_failure_path)
    end
  end

  describe "tracing access decisions" do
    it "records a granted access with what it was based on" do
      agent = create(:agent)

      expect { sign_in_via_proconnect(agent:) }.to change(AccessDecision, :count).by(1)

      expect(AccessDecision.last).to have_attributes(outcome: "granted", reason: nil,
        email: agent.email, siret: ProConnectTestHelper::TEST_SIRET, acr: "eidas1",
        organization_label: "Mairie de Test",
        agent_id: agent.id, membership_id: Membership.last.id)
    end

    # Le scope `idp_id` n'est pas encore demandé — il attend une habilitation ProConnect —
    # mais tout ce qui le consomme est en place : le jour où il arrive, il atterrit en base
    # sans autre changement que la ligne de scope.
    it "records which identity provider the agent came through" do
      sign_in_via_proconnect(agent: create(:agent), idp_id: "idp-dinum")

      expect(AccessDecision.last.idp_id).to eq("idp-dinum")
    end

    # Le chemin le plus long du dispositif : le before_action pose le contexte, Rails.event
    # le transporte, l'abonné le range en colonnes. Aucune spec unitaire ne l'éprouve.
    it "carries the request context all the way to the row" do
      sign_in_via_proconnect(agent: create(:agent))

      expect(AccessDecision.last.ip_address).to be_present
      expect(AccessDecision.last.request_id).to be_present
    end

    # L'abonnement du persisteur est couvert par les compteurs ci-dessus ; celui du
    # journaliseur ne l'est par rien — le retirer ne casserait aucune autre spec.
    it "logs the decision for the CSIRT as well as recording it" do
      # Rails journalise beaucoup pendant une requête : on laisse passer le reste et on
      # n'exige que notre ligne.
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(/event="Portail::Auth::Decision".*outcome=:granted/).at_least(:once)

      sign_in_via_proconnect(agent: create(:agent))
    end

    it "records a refusal with its reason" do
      mock_proconnect(sub: "sub-unknown", email: "alex@example.gouv.fr")

      proconnect_callback

      expect(AccessDecision.last).to have_attributes(outcome: "denied",
        reason: "unknown_agent", email: "alex@example.gouv.fr", agent_id: nil)
    end

    # L'agent est connu, aucun rattachement ne correspond : la ligne doit porter son sujet,
    # sinon la population que le pilotage veut compter n'a pas d'identité.
    it "records the agent on a refusal that has one, even without a membership" do
      agent = create(:agent, provider_sub: "sub-known")
      create(:membership, agent:, organization_link: create(:organization_link))
      mock_proconnect(sub: "sub-known", email: agent.email)

      proconnect_callback

      expect(AccessDecision.last).to have_attributes(outcome: "denied",
        reason: "organization_mismatch", agent_id: agent.id, membership_id: nil)
    end

    # Un jeton rejeté est la décision la plus intéressante du lot : quelqu'un a présenté
    # quelque chose qui ne tient pas, et elle n'a aucun sujet.
    it "records a rejected token, which has no subject at all" do
      mock_proconnect_transport(email: "a@b.fr")
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)

      proconnect_callback

      expect(AccessDecision.last).to have_attributes(outcome: "denied", reason: "invalid_token",
        email: nil)
    end

    it "tells a first identity binding from an ordinary sign-in" do
      agent = create(:agent, provider_sub: nil)
      link = OrganizationLink.find_or_create_by!(siret: ProConnectTestHelper::TEST_SIRET, insee_code: "00001")
      create(:membership, agent:, organization_link: link)
      mock_proconnect(sub: "sub-fresh", email: agent.email)

      proconnect_callback

      expect(AccessDecision.last.provider_sub_changed).to be(true)
    end

    it "leaves the flag down when the identity was already bound" do
      sign_in_via_proconnect(agent: create(:agent))

      expect(AccessDecision.last.provider_sub_changed).to be(false)
    end

    # L'invariant du ticket : tracer ne modifie jamais la décision. Rails ne l'applique
    # qu'en production — `raise_on_error` suit `consider_all_requests_local`, pour qu'un
    # abonné cassé se voie en développement. On éprouve donc le réglage de production.
    it "lets a legitimate agent in even when the recorder blows up" do
      Rails.event.raise_on_error = false
      expect(AccessDecision).to receive(:create!).and_raise(ActiveRecord::StatementInvalid)

      sign_in_via_proconnect(agent: create(:agent))

      expect(response).to redirect_to(root_path)
    ensure
      Rails.event.raise_on_error = true
    end
  end

  describe "second factor" do
    def administrator_agent
      create(:agent).tap do |agent|
        link = OrganizationLink.find_or_create_by!(siret: ProConnectTestHelper::TEST_SIRET, insee_code: "00001")
        create(:membership, :local_administrator, agent:, organization_link: link)
      end
    end

    # Plus aucune page intermédiaire : on repart de ProConnect vers ProConnect. C'est ce
    # que la phase requête d'OmniAuth interdisait, faute de pouvoir forger une demande
    # d'autorisation ailleurs que depuis un POST du navigateur.
    it "sends a single-factor administrator straight back to ProConnect" do
      agent = administrator_agent

      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])
      proconnect_callback

      expect(response).to redirect_to("https://proconnect.test/api/v2/authorize")
      expect(session[:proconnect_step_up]).to be(true)
    end

    # Certains FI imposent leur propre MFA avant que ProConnect ne la demande : l'acr
    # reste eidas1 mais l'amr du jeton vérifié en témoigne — rien à élever.
    it "lets an administrator in directly when the identity provider already imposed MFA" do
      agent = administrator_agent
      mock_proconnect(sub: agent.provider_sub, email: agent.email,
        acr: "eidas1", amr: ["pwd", "mfa"])

      proconnect_callback

      expect(response).to redirect_to(root_path)
      expect(ProviderSession.last).to be_granted
    end

    # L'agent vient de s'identifier : lui refaire saisir son adresse et rechoisir son
    # organisation serait gratuit. Les suggestions viennent du userinfo qu'on vient de
    # lire — elles ne transitent plus par la session, donc ne survivent à personne.
    it "suggests the address and the organisation it already knows" do
      agent = administrator_agent
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])

      expect(Portail::ProConnect::Client).to receive(:authorization)
        .with(step_up: false, login_hint: nil, siret_hint: nil)
        .and_return(Portail::ProConnect::Client::Authorization.new(
          url: "https://proconnect.test/api/v2/authorize",
          state: ProConnectTestHelper::STATE, nonce: ProConnectTestHelper::NONCE
        ))
      expect(Portail::ProConnect::Client).to receive(:authorization)
        .with(step_up: true, login_hint: agent.email,
          siret_hint: ProConnectTestHelper::TEST_SIRET)
        .and_return(Portail::ProConnect::Client::Authorization.new(
          url: "https://proconnect.test/api/v2/authorize", state: "s2", nonce: "n2"
        ))

      proconnect_callback
    end

    it "turns away a visitor who lands on the step-up page with nothing to raise" do
      get step_up_path

      expect(response).to redirect_to(root_path)
    end

    it "lets the administrator in once the second factor is presented" do
      agent = administrator_agent

      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])
      proconnect_callback
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1-mfa")
      proconnect_callback

      expect(response).to redirect_to(root_path)
      expect(ProviderSession.last).to be_granted
    end

    # Une seule élévation : ProConnect n'ayant pas relevé le niveau, redemander bouclerait.
    it "refuses when the step-up came back at the same level" do
      agent = administrator_agent

      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])
      proconnect_callback
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])
      proconnect_callback

      expect(response).to redirect_to(denied_path)
      expect(ProviderSession.last.denial_reason).to eq("second_factor_required")
    end

    # L'éjection porte un message que l'agent doit lire avant de repartir.
    it "explains itself when the agent was ejected mid-session" do
      agent = create(:agent)
      sign_in_via_proconnect(agent:, amr: ["pwd"])
      Membership.last.update!(role: "local_administrator")

      get root_path
      follow_redirect!

      expect(Capybara.string(response.body))
        .to have_text("Une authentification renforcée est requise")
    end

    # Le renvoi conserve ce qu'on savait de l'agent : ProConnect n'a rien à lui redemander.
    it "suggests the ejected agent's address and organisation on the way back" do
      agent = create(:agent)
      sign_in_via_proconnect(agent:, amr: ["pwd"])
      Membership.last.update!(role: "local_administrator")
      get root_path

      expect(Portail::ProConnect::Client).to receive(:authorization)
        .with(step_up: true, login_hint: agent.email,
          siret_hint: ProConnectTestHelper::TEST_SIRET)
        .and_return(Portail::ProConnect::Client::Authorization.new(
          url: "https://proconnect.test/api/v2/authorize", state: "s2", nonce: "n2"
        ))

      post proconnect_authorization_path

      expect(response).to redirect_to("https://proconnect.test/api/v2/authorize")
    end

    # Sans ça, une élévation interrompue par une panne laisserait ce navigateur exiger la
    # MFA de toute connexion suivante — y compris d'un autre agent sur un poste partagé.
    it "stops demanding a second factor once the journey has failed" do
      agent = administrator_agent
      mock_proconnect(sub: agent.provider_sub, email: agent.email, acr: "eidas1", amr: ["pwd"])
      proconnect_callback

      mock_proconnect_transport
      expect(Portail::ProConnect::TokenVerifier).to receive(:call)
        .and_raise(Portail::ProConnect::TokenVerifier::InvalidToken)
      proconnect_callback
      follow_redirect!

      expect(session[:proconnect_step_up]).to be_nil
    end

    it "never raises the requirement for an ordinary agent" do
      agent = create(:agent)

      sign_in_via_proconnect(agent:, acr: "eidas1")

      expect(response).to redirect_to(root_path)
      expect(session[:proconnect_step_up]).to be_nil
    end
  end
end
