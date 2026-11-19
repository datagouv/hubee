# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::Agents::Memberships::Update do
  let(:api_client) { build_stubbed(:oauth_application, name: "systeme-interne") }
  # Le cas standard : un membre habilité sur un flux.
  let!(:membership) do
    create(:membership).tap { create(:data_stream_access, membership: it, data_stream_code: "CERTDC") }
  end

  describe ".call" do
    def update(**attributes)
      form = API::Internal::V1::MembershipUpdateForm.new(membership:, **attributes)
      described_class.call(form:, api_client:, request_id: "req-1")
    end

    it "verifies the added codes only, then replaces the habilitations" do
      client = use_hub_api_fake_client
      expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "DECES", client:)
        .and_return(build_v2_data_stream(code: "DECES"))

      result = update(data_stream_codes: ["CERTDC", "DECES"])

      expect(result).to be_success
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to contain_exactly("CERTDC", "DECES")
    end

    it "writes nothing when the payload is invalid" do
      result = update(role: "local_administrator", data_stream_codes: [nil])

      expect(result).to be_failure
      expect(membership.reload.role).to eq("member")
      expect(Event.count).to eq(0)
    end

    it "refuses an unknown added code without writing" do
      stub_hub_api_v2_data_stream_not_found(code: "INCONNU")

      result = update(role: "local_administrator", data_stream_codes: ["INCONNU"])

      expect(result).to be_failure
      expect(result.refusals).to eq([[:unknown_data_stream, {code: "INCONNU"}]])
      expect(membership.reload.role).to eq("member")
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
      expect(Event.count).to eq(0)
    end

    it "writes nothing when hub-api does not answer" do
      stub_hub_api_v2_data_stream_error(code: "DECES")

      result = update(data_stream_codes: ["DECES"])

      expect(result).to be_failure
      expect(result.unavailable).to be(true)
      expect(membership.data_stream_accesses.pluck(:data_stream_code)).to eq(["CERTDC"])
      expect(Event.count).to eq(0)
    end
  end
end
