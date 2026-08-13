# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Deliveries", type: :request do
  let(:siret) { ProConnectTestHelper::TEST_SIRET }

  # Administrateur local : son périmètre n'est pas filtré, ce qui isole ce que chaque exemple
  # veut éprouver de la question des habilitations, traitée dans le spec de la policy.
  def sign_in_local_administrator
    agent = create(:agent, provider_sub: "sub-admin")
    sign_in_via_proconnect(agent: agent)
    Membership.find_by!(agent: agent).update!(role: "local_administrator")
    agent
  end

  describe "GET /demarches" do
    it "redirects a signed-out visitor to the home page" do
      get "/demarches"

      expect(response).to redirect_to(root_path)
    end

    it "lists the deliveries of the agent organisation" do
      sign_in_local_administrator
      stub_hub_api_v2_deliveries(siret, deliveries: [build_delivery_summary])

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("DGS-CERTDC-0000000000001-01")
      expect(Capybara.string(response.body)).to have_text("CERTDC")
    end

    it "opens on the transmitted state by default" do
      sign_in_local_administrator
      stub_hub_api_v2_deliveries(siret)

      get "/demarches"

      expect(HubApiV1::V2::Delivery).to have_received(:list)
        .with(hash_including(state: :transmitted))
    end

    it "honours the state requested as a parameter" do
      sign_in_local_administrator
      stub_hub_api_v2_deliveries(siret)

      get "/demarches", params: {statut: "acknowledged"}

      expect(HubApiV1::V2::Delivery).to have_received(:list)
        .with(hash_including(state: :acknowledged))
    end

    # Un paramètre trafiqué ne doit produire ni erreur applicative ni page blanche.
    it "falls back to the default state when the requested one is unknown" do
      sign_in_local_administrator

      get "/demarches", params: {statut: "n-importe-quoi"}

      expect(response).to redirect_to(demarches_path)
    end

    it "explains the lack of habilitation instead of showing a mute empty table" do
      agent = create(:agent, provider_sub: "sub-membre")
      sign_in_via_proconnect(agent: agent)

      get "/demarches"

      expect(response).to have_http_status(:success)
      expect(Capybara.string(response.body)).to have_text("aucun flux")
    end

    context "when the upstream API is failing" do
      it "renders the page with an alert rather than a server error" do
        sign_in_local_administrator
        stub_hub_api_v2_deliveries_error(siret)

        get "/demarches"

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("momentanément indisponible")
      end

      it "names the perimeter ambiguity, which calls for a different action" do
        sign_in_local_administrator
        stub_hub_api_v2_organization_ambiguous(siret)

        get "/demarches"

        expect(response).to have_http_status(:success)
        expect(Capybara.string(response.body)).to have_text("plusieurs organisations")
      end
    end
  end
end
