# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::BaseController, type: :controller do
  controller(described_class) do
    skip_before_action :doorkeeper_authorize!

    def index
      raise ActiveRecord::RecordNotFound
    end
  end

  it "answers a missing record with the same JSON 404 as an unknown URL" do
    get :index

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to eq("error" => "Ressource introuvable.")
  end
end
