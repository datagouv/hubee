# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create::CheckDataStreams do
  describe ".call" do
    def validated_form(**attributes)
      build(:api_internal_agent_form, **attributes).tap(&:validate)
    end

    it "lets through every data stream code hub-api knows" do
      client = use_hub_api_fake_client
      expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "CERTDC", client:)
        .and_return(build_v2_data_stream(code: "CERTDC"))
      expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "AEC", client:)
        .and_return(build_v2_data_stream(code: "AEC"))

      result = described_class.call(form: validated_form(data_stream_codes: ["CERTDC", "AEC"]))

      expect(result).to be_success
      expect(result.refusals).to be_nil
      expect(result.unavailable).to be_nil
    end

    it "refuses each unknown code among known ones, after the reasons already found" do
      stub_hub_api_v2_data_stream(code: "CERTDC")
      stub_hub_api_v2_data_stream_not_found(code: "INCONNU")
      stub_hub_api_v2_data_stream_not_found(code: "AUTRE")

      result = described_class.call(
        form: validated_form(data_stream_codes: ["INCONNU", "CERTDC", "AUTRE"]), refusals: [:already_attached]
      )

      expect(result).to be_success
      expect(result.refusals).to eq([
        :already_attached, [:unknown_data_stream, {code: "INCONNU"}], [:unknown_data_stream, {code: "AUTRE"}]
      ])
    end

    it "asks hub-api once about a code sent twice" do
      expect(HubApiV1::V2::DataStream).to receive(:find).with(hash_including(code: "CERTDC")).once
        .and_return(build_v2_data_stream(code: "CERTDC"))

      expect(described_class.call(form: validated_form(data_stream_codes: ["CERTDC", "CERTDC"]))).to be_success
    end

    it "notes hub-api unavailable without refusing, and logs it" do
      stub_hub_api_v2_data_stream_error(code: "CERTDC")
      expect(Rails.logger).to receive(:error).with(/\ARéférentiel des flux indisponible — /)

      result = described_class.call(form: validated_form)

      expect(result).to be_success
      expect(result.unavailable).to be(true)
      expect(result.refusals).to be_nil
    end

    it "keeps the unknown codes found before hub-api fails, and asks nothing after" do
      client = use_hub_api_fake_client
      expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "INCONNU", client:)
        .and_raise(HubApiV1::V2::DataStreamNotFoundError)
      expect(HubApiV1::V2::DataStream).to receive(:find).with(code: "CERTDC", client:)
        .and_raise(HubApiV1::Client::ServerError)
      expect(HubApiV1::V2::DataStream).not_to receive(:find).with(code: "AEC", client:)

      result = described_class.call(form: validated_form(data_stream_codes: ["INCONNU", "CERTDC", "AEC"]))

      expect(result.refusals).to eq([[:unknown_data_stream, {code: "INCONNU"}]])
      expect(result.unavailable).to be(true)
    end

    # Un administrateur local sans habilitation a accès à tous les flux, sans rien demander.
    it "asks hub-api nothing for a local administrator without habilitation" do
      expect(HubApiV1::V2::DataStream).not_to receive(:find)

      result = described_class.call(form: validated_form(role: "local_administrator", data_stream_codes: []))

      expect(result).to be_success
      expect(result.refusals).to be_nil
    end

    it "does not ask hub-api about codes that already have their reason" do
      expect(HubApiV1::V2::DataStream).not_to receive(:find)

      result = described_class.call(form: validated_form(data_stream_codes: ["CERTDC", "AVEC ESPACE"]))

      expect(result).to be_success
      expect(result.refusals).to be_nil
    end
  end
end
