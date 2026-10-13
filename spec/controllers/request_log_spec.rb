# frozen_string_literal: true

require "rails_helper"

RSpec.describe RequestLog, type: :controller do
  controller(ActionController::Base) do
    rescue_from(KeyError) { head :not_found }

    def index
      raise KeyError, "clé absente"
    rescue KeyError
      raise ArgumentError, "enveloppe"
    end
  end

  it "names the exception the handler took, which may be the cause of the one raised" do
    events = capture_semantic_logger_events { get :index }

    expect(response).to have_http_status(:not_found)
    expect(events).to include(be_a_semantic_logger_event(message: "Completed #index",
      payload_includes: {rescued_exception_class: "KeyError", rescued_exception_message: "clé absente"}))
  end
end
