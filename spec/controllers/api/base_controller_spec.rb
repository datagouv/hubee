# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::BaseController, type: :controller do
  controller(described_class) do
    skip_before_action :doorkeeper_authorize!

    def index
      raise ActiveRecord::RecordNotFound
    end

    def show = render(plain: request.format.to_s)
  end

  it "answers a missing record with the same JSON 404 as an unknown URL" do
    get :index

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to eq("error" => "not_found", "message" => "Ressource introuvable.")
  end

  it "sets the JSON format whatever the client asks for" do
    request.headers["Accept"] = "text/html"

    get :show, params: {id: "1"}

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("application/json")
  end
end
