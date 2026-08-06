# frozen_string_literal: true

require "rails_helper"

# Aucune page du portail n'est encore réservée. On en route donc une, anonyme et locale
# à ce fichier, pour éprouver le garde sur un vrai cycle de requête plutôt que de se
# contenter de regarder la chaîne de rappels.
RSpec.describe Portail::BaseController, type: :controller do
  controller do
    def index
      head :ok
    end

    def create
      head :ok
    end
  end

  def sign_in(created_at: Time.current, updated_at: Time.current)
    provider_session = create(:provider_session, membership: create(:membership),
      created_at:, updated_at:)
    session[:provider_session_id] = provider_session.id
  end

  describe "the guard" do
    # La requête est mémorisée avec sa chaîne de paramètres : sans elle, l'agent
    # reviendrait sur la page en ayant perdu son filtre ou sa pagination.
    it "turns an anonymous visitor away and remembers where they were going" do
      get :index, params: {filtre: "actif"}

      expect(response).to redirect_to(root_path)
      expect(session[:return_to]).to eq("/portail/base?filtre=actif")
    end

    it "lets an authenticated agent through" do
      sign_in

      get :index

      expect(response).to have_http_status(:ok)
      expect(session[:return_to]).to be_nil
    end

    # Rejouer un POST après une reconnexion n'aurait pas de sens, et mémoriser sa cible
    # laisserait croire le contraire.
    it "does not remember a non-GET destination" do
      post :create

      expect(response).to redirect_to(root_path)
      expect(session[:return_to]).to be_nil
    end
  end

  describe "session expiry" do
    # Le message lui-même se vérifie là où l'agent le lit, une fois la redirection suivie
    # (spec/requests) : ici, `flash[:alert]` passerait au vert même posé en flash.now.
    it "closes a session left idle" do
      sign_in(updated_at: 31.minutes.ago)

      get :index

      expect(response).to redirect_to(root_path)
      expect(session[:provider_session_id]).to be_nil
    end

    it "closes a session that reached its absolute lifetime, however active" do
      sign_in(created_at: 13.hours.ago)

      get :index

      expect(response).to redirect_to(root_path)
      expect(session[:provider_session_id]).to be_nil
    end

    # L'enregistrement disparaît avec la session : il ne doit pas figurer dans un
    # inventaire des sessions ouvertes.
    it "destroys the record of the session it closes" do
      sign_in(updated_at: 31.minutes.ago)

      expect { get :index }.to change(ProviderSession, :count).by(-1)
    end

    # Une écriture par requête serait inutilement coûteuse.
    it "does not touch the record more than once a minute" do
      sign_in(updated_at: 10.seconds.ago)

      expect { get :index }.not_to change { ProviderSession.last.updated_at }
    end

    # Le second facteur se relit comme l'autorisation : un rattachement devenu à
    # privilèges pendant la session ne doit pas la laisser se poursuivre.
    it "closes a session whose membership became privileged mid-flight" do
      provider_session = create(:provider_session,
        membership: create(:membership, :local_administrator), acr: "eidas1")
      session[:provider_session_id] = provider_session.id

      get :index

      # Vers l'élévation, pas vers l'accueil : l'agent éjecté doit savoir quoi faire, et
      # le marqueur fait exiger la MFA dès la première autorisation suivante.
      expect(response).to redirect_to(step_up_path)
      expect(session[:provider_session_id]).to be_nil
      expect(session[:proconnect_step_up]).to be(true)
    end

    it "records the session it closes for want of a second factor" do
      membership = create(:membership, :local_administrator)
      session[:provider_session_id] = create(:provider_session, membership:, acr: "eidas1").id

      expect { get :index }.to change(AccessDecision, :count).by(1)
      expect(AccessDecision.last).to have_attributes(outcome: "denied",
        reason: "second_factor_required", membership_id: membership.id)
    end

    it "leaves a privileged session alone once it carries a second factor" do
      provider_session = create(:provider_session,
        membership: create(:membership, :local_administrator), acr: "eidas1-mfa")
      session[:provider_session_id] = provider_session.id

      get :index

      expect(response).to have_http_status(:ok)
    end
  end

  # Le contexte évite d'élargir la signature de toute la chaîne : aucun interactor ne reçoit
  # l'IP, et elle arrive quand même dans la trace.
  describe "the event context" do
    it "carries what identifies the request" do
      request.headers["User-Agent"] = "Firefox"
      expect(Rails.event).to receive(:set_context) do |context|
        expect(context).to include(:ip_address, :request_id)
        expect(context[:user_agent]).to eq("Firefox")
      end

      get :index
    end
  end

  describe ".allow_unauthenticated_access" do
    def authentication_required?(controller_class)
      controller_class._process_action_callbacks.any? { |callback| callback.filter == :require_authentication }
    end

    # Ces trois-là doivent rester joignables sans session, sous peine de boucle sur
    # l'accueil ou de page d'erreur transformée en redirection.
    it "is declared by every controller that must stay reachable" do
      expect(authentication_required?(Portail::DashboardController)).to be(false)
      expect(authentication_required?(Portail::ErrorsController)).to be(false)
      expect(authentication_required?(Portail::SessionsController)).to be(false)
    end

    def second_factor_enforced?(controller_class)
      controller_class._process_action_callbacks.any? { |callback| callback.filter == :enforce_second_factor! }
    end

    # Entrer et sortir doit rester possible : un agent dont les droits viennent de changer
    # se ferait sinon éjecter au moment où il essaie de se déconnecter, et sa session
    # ProConnect resterait ouverte.
    it "never gets between an agent and the sign-out path" do
      expect(second_factor_enforced?(Portail::SessionsController)).to be(false)
      expect(second_factor_enforced?(Portail::DashboardController)).to be(true)
    end
  end
end
