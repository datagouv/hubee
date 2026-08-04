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

  let(:membership) { create(:membership) }

  def sign_in(created_at: Time.current, updated_at: Time.current)
    provider_session = create(:provider_session, membership:, created_at:, updated_at:)
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
    it "closes a session left idle and says so" do
      sign_in(updated_at: 31.minutes.ago)

      get :index

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("Votre session a expiré")
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
  end
end
