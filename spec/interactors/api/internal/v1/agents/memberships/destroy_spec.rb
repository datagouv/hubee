# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Memberships::Destroy do
  let(:api_client) { build_stubbed(:oauth_application, name: "systeme-interne") }
  # Le cas standard : un membre habilité sur un flux.
  let!(:membership) do
    create(:membership).tap { create(:data_stream_access, membership: it, data_stream_code: "CERTDC") }
  end

  describe ".call" do
    it "removes the membership and records the trace" do
      result = described_class.call(membership:, api_client:, request_id: "req-1")

      expect(result).to be_success
      expect(Membership.exists?(membership.id)).to be(false)
      expect(Event.sole.event_type).to eq("membership.deleted")
    end
  end
end
