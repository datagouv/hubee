# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Portail::Dashboard", type: :request do
  describe "GET /portail" do
    it "returns http success" do
      get "/portail"
      expect(response).to have_http_status(:success)
    end
  end
end
