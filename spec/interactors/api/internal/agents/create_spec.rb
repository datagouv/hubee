# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create do
  let(:api_client) { build_stubbed(:oauth_application, name: "systeme-interne") }

  describe ".call" do
    it "registers an agent in an organisation the referential confirms" do
      stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
      stub_hub_api_v2_data_stream(code: "CERTDC")
      form = build(:api_internal_agent_form, email: "alice.martin@ville.fr")

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result).to be_success
      expect(result.membership).to have_attributes(persisted?: true, role: "member", data_stream_codes: ["CERTDC"])
      expect(result.membership.agent.email).to eq("alice.martin@ville.fr")
    end

    # Chaque vérification porte sur les champs valides, et la demande reçoit tous ses motifs.
    it "gathers every reason of a refused request and writes nothing" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75101"))
      stub_hub_api_organization_not_found(siret: "21750056000016")
      stub_hub_api_v2_data_stream_not_found(code: "CERTDC")
      form = build(:api_internal_agent_form, email: "alice.martin@ville.fr", phone_number: "abc")

      result = nil
      expect { result = described_class.call(form:, api_client:, request_id: "req-1") }
        .not_to change { [Agent.count, OrganizationLink.count, Membership.count, Event.count] }

      expect(result).to be_failure
      expect(result.refusals).to eq([:siret_already_attached, :unknown_organization, [:unknown_data_stream, {code: "CERTDC"}]])
      expect(form.errors.details).to eq(phone_number: [{error: :invalid, value: "abc"}])
      expect(result.membership).to be_nil
    end
  end
end
