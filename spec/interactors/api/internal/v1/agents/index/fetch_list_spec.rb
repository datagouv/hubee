# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Index::FetchList do
  describe ".call" do
    def attach(email, siret:)
      membership = create(:membership, agent: create(:agent, email:),
        organization_link: OrganizationLink.find_or_create_by!(siret:, insee_code: "75056"))
      create(:data_stream_access, membership:, data_stream_code: "CERTDC")
      membership.agent
    end

    it "puts in the context the agents matching the criteria, by address" do
      bob = attach("bob.durand@ville.fr", siret: "21750056000016")
      alice = attach("alice.martin@ville.fr", siret: "21750056000016")
      attach("carole.petit@ville.fr", siret: "13002526500013")
      form = API::Internal::V1::AgentSearchForm.new(siret: "21750056000016")

      result = described_class.call(form:)

      expect(result).to be_success
      expect(result.agents).to eq([alice, bob])
    end

    it "puts every agent in the context without criteria" do
      agents = [attach("alice.martin@ville.fr", siret: "21750056000016"), attach("carole.petit@ville.fr", siret: "13002526500013")]

      expect(described_class.call(form: API::Internal::V1::AgentSearchForm.new).agents).to eq(agents)
    end
  end
end
