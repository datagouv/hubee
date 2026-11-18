# frozen_string_literal: true

require "rails_helper"

# Un contrôleur anonyme, local à ce fichier : le garde s'éprouve sur un vrai cycle de requête, sans
# dépendre d'une page réelle.
RSpec.describe Portail::BaseController, type: :controller do
  controller do
    skip_after_action :verify_authorized, :verify_policy_scoped

    requires_reauthentication :sensitive, only: :index, purpose: -> { "export:#{params[:id]}" }
    requires_reauthentication :very_sensitive, only: :create, purpose: -> { "credentials:#{params[:id]}" }
    requires_reauthentication :very_sensitive, only: :update, purpose: -> { "credentials:#{params[:id]}" },
      with: :explain_reauthentication

    def index = head(:ok)

    def create = head(:ok)

    def update = head(:ok)

    private

    def explain_reauthentication = render(plain: "vérifiez votre identité", status: :forbidden)
  end

  let(:provider_session) { create(:provider_session) }

  before do
    freeze_time
    session[:provider_session_id] = provider_session.id
  end

  def prove(purpose)
    Portail::Access::Reauthentication.record!(provider_session, purpose:, id_token: "fresh-id-token",
      acr: "eidas1-mfa", amr: ["mfa"])
  end

  # La preuve est datée plutôt que l'horloge avancée : au-delà de 30 minutes, la session elle-même
  # expirerait par inactivité.
  it "lets a sensitive action through after a recent reauthentication" do
    prove("credentials:42")
    provider_session.update_column(:reauthenticated_at, 29.minutes.ago)

    get :index, params: {id: "7"}

    expect(response).to have_http_status(:ok)
  end

  it "refuses a sensitive action without a reauthentication of less than 30 minutes" do
    prove("credentials:42")
    provider_session.update_column(:reauthenticated_at, 31.minutes.ago)

    get :index, params: {id: "7"}

    expect(response).to have_http_status(:forbidden)
  end

  it "lets a very sensitive action through once, then refuses it" do
    prove("credentials:42")

    post :create, params: {id: "42"}
    expect(response).to have_http_status(:ok)

    post :create, params: {id: "42"}
    expect(response).to have_http_status(:forbidden)
  end

  it "refuses a very sensitive action proved for another purpose" do
    prove("credentials:41")

    post :create, params: {id: "42"}

    expect(response).to have_http_status(:forbidden)
    expect(provider_session.reload.reauthentication_consumed_at).to be_nil
  end

  it "hands the refusal to the declared handler" do
    patch :update, params: {id: "42"}

    expect(response).to have_http_status(:forbidden)
    expect(response.body).to eq("vérifiez votre identité")
  end

  it "rejects an unknown level at declaration" do
    expect {
      Class.new(Portail::BaseController) { requires_reauthentication :secret, purpose: -> { "x" } }
    }.to raise_error(ArgumentError, /secret/)
  end
end
