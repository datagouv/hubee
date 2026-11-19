# frozen_string_literal: true

require "rails_helper"

RSpec.describe "filter_parameter_logging" do
  subject(:filtered) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(parameters) }

  describe "the agent search of the internal API" do
    let(:parameters) { {"search" => "alice.martin@ville.fr", "siret" => "21750056000016", "role" => "member"} }

    it "filters the searched text and keeps the other criteria readable" do
      expect(filtered).to eq({"search" => "[FILTERED]", "siret" => "21750056000016", "role" => "member"})
    end
  end
end
