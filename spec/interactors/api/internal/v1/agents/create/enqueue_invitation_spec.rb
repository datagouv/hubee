# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Create::EnqueueInvitation do
  include ActiveJob::TestHelper

  describe ".call" do
    let(:agent) { create(:agent) }
    let(:membership) { create(:membership, agent:) }
    let(:api_client) { create(:oauth_application, name: "systeme-interne") }

    def enqueue(send_invitation:, agent_created:, organization_name: "Mairie de Paris")
      form = build(:api_internal_v1_agent_form, send_invitation:, siret: "21750056000016", insee_code: "75056")
      described_class.call(form:, membership:, agent_created:, organization_name:, api_client:, request_id: "req-42")
    end

    it "enqueues the invitation of an agent created by a call that asked for it" do
      result = enqueue(send_invitation: true, agent_created: true)

      expect(result).to be_success
      expect(API::InviteAgentJob).to have_been_enqueued.exactly(:once)
        .with(
          agent,
          organization_name: "Mairie de Paris", siret: "21750056000016", insee_code: "75056",
          api_client: "systeme-interne", api_client_uid: api_client.uid, request_id: "req-42"
        )
    end

    it "enqueues the invitation without a name when the referential had none" do
      enqueue(send_invitation: true, agent_created: true, organization_name: nil)

      expect(API::InviteAgentJob).to have_been_enqueued.with(
        agent,
        organization_name: nil, siret: "21750056000016", insee_code: "75056",
        api_client: "systeme-interne", api_client_uid: api_client.uid, request_id: "req-42"
      )
    end

    {
      "an invitation not asked for" => {send_invitation: false, agent_created: true},
      "an agent that already existed" => {send_invitation: true, agent_created: false}
    }.each do |case_name, arguments|
      it "enqueues nothing for #{case_name}" do
        result = enqueue(**arguments)

        expect(result).to be_success
        expect(API::InviteAgentJob).not_to have_been_enqueued
      end
    end

    it "succeeds and reports the failure when the job cannot be enqueued" do
      error = ActiveJob::EnqueueError.new("queue down")
      expect(API::InviteAgentJob).to receive(:perform_later).and_raise(error)
      expect(Rails.error).to receive(:report).with(error, handled: true)

      expect(enqueue(send_invitation: true, agent_created: true)).to be_success
    end
  end
end
