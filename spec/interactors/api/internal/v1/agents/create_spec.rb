# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Create do
  include ActiveJob::TestHelper

  let(:api_client) { build_stubbed(:oauth_application, name: "systeme-interne") }

  describe ".call" do
    it "registers an agent in an organisation the referential confirms" do
      stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
      stub_hub_api_v2_data_stream(code: "CERTDC")
      form = build(:api_internal_v1_agent_form, email: "alice.martin@ville.fr")

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(result).to be_success
      expect(result.membership).to have_attributes(persisted?: true, role: "member", data_stream_codes: ["CERTDC"])
      expect(result.membership.agent.email).to eq("alice.martin@ville.fr")
    end

    it "keeps the effective invitation in the context for the steps that follow" do
      stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")
      stub_hub_api_v2_data_stream(code: "CERTDC")

      results = [build(:api_internal_v1_agent_form), build(:api_internal_v1_agent_form, send_invitation: true)].map do
        described_class.call(form: it, api_client:, request_id: "req-1")
      end

      expect(results.map { it.form.send_invitation }).to eq([false, true])
    end

    it "enqueues the invitation with the name confirmed by the referential once the agent is registered" do
      stub_hub_api_organization_found(
        siret: "21750056000016", type: "SI", branch_code: "75056",
        record: build_organization_record(name: "Mairie de Paris", siret: "21750056000016", type: "SI", branch_code: "75056")
      )
      stub_hub_api_v2_data_stream(code: "CERTDC")
      form = build(:api_internal_v1_agent_form, send_invitation: true)

      result = described_class.call(form:, api_client:, request_id: "req-1")

      expect(API::InviteAgentJob).to have_been_enqueued.exactly(:once)
        .with(
          result.membership.agent,
          organization_name: "Mairie de Paris", siret: "21750056000016", insee_code: "75056",
          api_client: "systeme-interne", api_client_uid: api_client.uid, request_id: "req-1"
        )
    end

    # Chaque vérification porte sur les champs valides, et la demande reçoit tous ses motifs.
    it "gathers every reason of a refused request and writes nothing" do
      agent = create(:agent, email: "alice.martin@ville.fr")
      create(:membership, agent:, organization_link: create(:organization_link, siret: "21750056000016", insee_code: "75101"))
      stub_hub_api_organization_not_found(siret: "21750056000016")
      stub_hub_api_v2_data_stream_not_found(code: "CERTDC")
      form = build(:api_internal_v1_agent_form, email: "alice.martin@ville.fr", phone_number: "abc", send_invitation: true)

      result = nil
      expect { result = described_class.call(form:, api_client:, request_id: "req-1") }
        .not_to change { [Agent.count, OrganizationLink.count, Membership.count, Event.count] }

      expect(result).to be_failure
      expect(result.refusals).to eq([:siret_already_attached, :unknown_organization, [:unknown_data_stream, {code: "CERTDC"}]])
      expect(form.errors.details).to eq(phone_number: [{error: :invalid, value: "abc"}])
      expect(result.membership).to be_nil
      expect(API::InviteAgentJob).not_to have_been_enqueued
    end
  end
end
