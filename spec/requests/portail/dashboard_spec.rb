# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Dashboard", type: :request do
  describe "GET /" do
    it "shows the home page to a signed-out visitor" do
      get "/"

      expect(response).to have_http_status(:success)
    end

    it "sends a signed-in agent to their deliveries" do
      agent = create(:agent, provider_sub: "sub-connecte")
      sign_in_via_proconnect(agent: agent)

      get "/"

      expect(response).to redirect_to(demarches_path)
    end
  end
end
