# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Index do
  describe ".call" do
    # Le cas standard : un membre habilité sur un flux, retrouvé par son SIRET.
    it "hands back the agents matching the criteria" do
      membership = create(:membership, organization_link: create(:organization_link, siret: "21750056000016"))
      create(:data_stream_access, membership:, data_stream_code: "CERTDC")
      create(:membership, organization_link: create(:organization_link, siret: "13002526500013"))
      form = API::Internal::V1::AgentSearchForm.new(siret: "21750056000016")

      result = described_class.call(form:)

      expect(result).to be_success
      expect(result.agents).to eq([membership.agent])
    end

    # Le refus de l'organizer entier : la première étape le rend, aucune recherche ne part.
    it "refuses invalid criteria without searching" do
      expect(API::Internal::V1::AgentsQuery).not_to receive(:new)
      form = API::Internal::V1::AgentSearchForm.new(insee_code: "75056")

      result = described_class.call(form:)

      expect(result).to be_failure
      expect(result.error).to eq(:invalid_criteria)
      expect(form.errors.details).to eq(insee_code: [{error: :requires_siret}])
    end
  end
end
