# frozen_string_literal: true

require "rails_helper"

# Un contrôleur anonyme, local à ce fichier : le garde s'éprouve sur un vrai cycle de requête, sans
# dépendre d'une page réelle.
RSpec.describe Portail::BaseController, type: :controller do
  controller do
    skip_after_action :verify_authorized, :verify_policy_scoped

    requires_reauthentication :export, only: :index,
      subject: -> { params[:id] }, return_to: -> { "/exports/#{params[:id]}" }
    requires_reauthentication :credentials, only: :create,
      subject: -> { params[:id] }, return_to: -> { "/abonnements/#{params[:id]}" }
    requires_reauthentication :unclassed, only: :destroy,
      subject: -> { params[:id] }, return_to: -> { "/" }

    def index = head(:ok)

    def create = head(:ok)

    def destroy = head(:ok)

    # Ce qu'une page lirait pour proposer l'action.
    def show
      status = reauthentication_status(:credentials, params[:id])
      render(plain: "#{status.unlocked?} #{status.unlocked_until}")
    end
  end

  let(:provider_session) { create(:provider_session) }
  let(:logout_url) { "https://proconnect.test/api/v2/session/end?id_token_hint=x" }

  # Aucune action réelle n'est encore « sensible » : celle-ci n'est classée que le temps des exemples.
  before do
    stub_const("Portail::Access::Reauthentication::ACTIONS", {export: :sensitive, credentials: :very_sensitive})
    freeze_time
    session[:provider_session_id] = provider_session.id
  end

  def prove(purpose)
    Portail::Access::Reauthentication.record!(provider_session, purpose:, id_token: "fresh-id-token",
      acr: "eidas1-mfa", amr: ["mfa"])
  end

  def expect_logout
    expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
      .with(id_token: provider_session.provider_id_token).and_return(logout_url)
  end

  # La preuve est datée plutôt que l'horloge avancée : au-delà de 30 minutes, la session elle-même
  # expirerait par inactivité.
  it "lets a sensitive action through after a recent reauthentication" do
    prove("credentials:42")
    provider_session.update_column(:reauthenticated_at, 29.minutes.ago)

    get :index, params: {id: "7"}

    expect(response).to have_http_status(:ok)
  end

  it "departs for a reauthentication when a sensitive action has no proof of less than 30 minutes" do
    prove("credentials:42")
    provider_session.update_column(:reauthenticated_at, 31.minutes.ago)
    expect_logout

    get :index, params: {id: "7"}

    expect(response).to redirect_to(logout_url)
  end

  it "lets a very sensitive action through once, then departs for a reauthentication" do
    prove("credentials:42")

    post :create, params: {id: "42"}
    expect(response).to have_http_status(:ok)

    expect_logout
    post :create, params: {id: "42"}
    expect(response).to redirect_to(logout_url)
  end

  it "does not let a very sensitive action through on a proof for another subject" do
    prove("credentials:41")
    expect_logout

    post :create, params: {id: "42"}

    expect(response).to redirect_to(logout_url)
    expect(provider_session.reload.reauthentication_consumed_at).to be_nil
  end

  # Tout ce que la suite du parcours relit vient de la requête interceptée, rien du navigateur.
  it "remembers the intercepted action, with its purpose and the way back" do
    expect_logout

    post :create, params: {id: "42"}

    expect(session[:reauthentication]).to eq("action" => "credentials",
      "purpose" => "credentials:42", "return_to" => "/abonnements/42",
      "provider_session_id" => provider_session.id, "started_at" => Time.current.to_i)
  end

  # Rien n'a été fermé : l'agent reste connecté et retrouve sa page.
  it "brings the agent back when ProConnect cannot be reached" do
    expect(Portail::ProConnect::Client).to receive(:reauthentication_logout_url)
      .and_raise(Portail::ProConnect::Client::Unavailable)

    post :create, params: {id: "42"}

    expect(response).to redirect_to("/abonnements/42")
    expect(flash[:alert]).to eq("La vérification de votre identité n'a pas abouti. Réessayez.")
    expect(session[:reauthentication]).to be_nil
  end

  # Une action gardée sans être classée n'a pas de niveau : elle échoue plutôt que de passer.
  it "fails on an action that is not classed" do
    expect { delete :destroy, params: {id: "42"} }.to raise_error(ArgumentError, /unclassed/)
  end

  # Sans rien consommer : la page ne fait que dire où en est l'agent.
  it "tells a page until when an action is unlocked on a subject, without consuming the proof" do
    prove("credentials:42")

    get :show, params: {id: "42"}
    expect(response.body).to eq("true #{5.minutes.from_now}")

    get :show, params: {id: "41"}
    expect(response.body).to eq("false ")
    expect(provider_session.reload.reauthentication_consumed_at).to be_nil
  end
end
