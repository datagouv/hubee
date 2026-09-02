# frozen_string_literal: true

require "rails_helper"

# Fermé par défaut : un contrôleur du portail qui n'autorise rien est refusé, sauf déclaration
# explicite. Un contrôleur anonyme, pour ne dépendre d'aucune page réelle.
RSpec.describe Portail::BaseController, type: :controller do
  controller do
    allow_unauthenticated_access

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
    membership = create(:membership)
    session[:provider_session_id] = create(:provider_session, membership: membership).id
    # Rails émet ses propres événements pendant la requête : on capture tout, on cherche le nôtre.
    events = []
    expect(Rails.event).to receive(:notify).at_least(:once) { |*args| events << args }

    delete :destroy, params: {id: "1"}

    expect(response).to have_http_status(:not_found)
    expect(events).to include(["portail.access.refused",
      {path: "/portail/base/1", agent_id: membership.agent_id, membership_id: membership.id}])
  end
end
