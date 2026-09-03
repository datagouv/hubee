# frozen_string_literal: true

require "rails_helper"

# Fermé par défaut : un contrôleur du portail qui n'autorise rien est refusé, sauf déclaration
# explicite. Des contrôleurs anonymes, pour ne dépendre d'aucune page réelle.
RSpec.describe Portail::BaseController, type: :controller do
  let(:membership) { create(:membership) }

  before { session[:provider_session_id] = create(:provider_session, membership: membership).id }

  context "on a controller reserved to agents" do
    controller do
      def index = head(:ok)

      def show = head(:ok)

      def destroy = raise(Pundit::NotAuthorizedError)
    end

    it "refuses a collection action that scoped no policy" do
      expect { get :index }.to raise_error(Pundit::PolicyScopingNotPerformedError)
    end

    it "refuses a member action that authorized nothing" do
      expect { get :show, params: {id: "1"} }.to raise_error(Pundit::AuthorizationNotPerformedError)
    end

    # Un refus rend la même page qu'une ressource inexistante : distinguer les deux révélerait
    # l'existence de ce que l'agent n'a pas à voir. Seule la décision d'accès émise les sépare.
    it "renders a not found page on a refusal, and emits the access decision" do
      # Rails émet ses propres événements pendant la requête : on capture tout, on cherche le nôtre.
      events = []
      expect(Rails.event).to receive(:notify).at_least(:once) { |*args| events << args }

      delete :destroy, params: {id: "1"}

      expect(response).to have_http_status(:not_found)
      expect(events).to include([Portail::Access::Decision.new(outcome: :refused,
        path: "/portail/base/1", agent_id: membership.agent_id, membership_id: membership.id)])
    end
  end

  # La déclaration qui ouvre un contrôleur aux visiteurs lève aussi les deux gardes. Éprouvé
  # avec un agent connecté : c'est lui que l'accueil redirige, et l'ouverture ne l'exempte pas
  # de l'authentification, seulement de la vérification.
  context "on a controller open to visitors" do
    controller do
      allow_unauthenticated_access

      def index = head(:ok)

      def show = head(:ok)
    end

    it "verifies neither the policy scope nor the authorization" do
      get :index
      expect(response).to have_http_status(:ok)

      get :show, params: {id: "1"}
      expect(response).to have_http_status(:ok)
    end
  end
end
