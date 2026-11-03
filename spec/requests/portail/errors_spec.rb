# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail errors", :production_exceptions, type: :request do
  it "renders the DSFR 404 page for an unknown URL" do
    get "/inconnue"

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Page introuvable", "fr-footer")
  end

  it "renders the DSFR 404 page for an unknown URL that only starts like the API" do
    get "/apidoc"

    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Page introuvable")
  end

  it "renders the DSFR 500 page for an unexpected error, and reports it" do
    sign_in_via_proconnect(agent: create(:agent))
    expect(ProviderSession).to receive(:includes).and_raise(ActiveRecord::ConnectionNotEstablished)

    reported = errors_reported_during { get "/" }

    expect(response).to have_http_status(:internal_server_error)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("Une erreur est survenue", "fr-footer")
    expect(reported).to contain_exactly(an_instance_of(ActiveRecord::ConnectionNotEstablished))
  end
end
