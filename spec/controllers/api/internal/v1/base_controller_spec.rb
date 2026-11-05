# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::BaseController, type: :controller do
  controller(described_class) do
    skip_before_action :doorkeeper_authorize!

    def index
      raise Pundit::NotAuthorizedError
    end
  end

  it "answers a right the client lacks with a JSON 403" do
    get :index

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to eq("error" => "forbidden", "message" => "Ce client n'a pas le droit d'effectuer cette opération.")
  end
end
