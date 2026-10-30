# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create::CheckOrganization do
  describe ".call" do
    def validated_form(**attributes)
      build(:api_internal_agent_form, **attributes).tap(&:validate)
    end

    it "refuses an organisation the V2 knows once the referential no longer has it" do
      create(:organization_link, siret: "21750056000016", insee_code: "75056")
      stub_hub_api_organization_not_found(siret: "21750056000016")

      result = described_class.call(form: validated_form)

      expect(result).to be_success
      expect(result.refusals).to eq([:unknown_organization])
    end

    it "lets through an organisation unknown to the V2 that the referential confirms" do
      stub_hub_api_organization_found(siret: "21750056000016", type: "SI", branch_code: "75056")

      result = described_class.call(form: validated_form)

      expect(result).to be_success
      expect(result.refusals).to be_nil
      expect(result.unavailable).to be_nil
    end

    it "refuses an organisation unknown to the referential, after the reasons already found" do
      stub_hub_api_organization_not_found(siret: "21750056000016")

      result = described_class.call(form: validated_form, refusals: [:siret_already_attached])

      expect(result).to be_success
      expect(result.refusals).to eq([:siret_already_attached, :unknown_organization])
    end

    it "notes an unavailable referential without refusing, and logs it" do
      stub_hub_api_organization_error(siret: "21750056000016")
      expect(Rails.logger).to receive(:error).with(/\ARéférentiel des organisations indisponible — /)

      result = described_class.call(form: validated_form)

      expect(result).to be_success
      expect(result.unavailable).to be(true)
      expect(result.refusals).to be_nil
    end

    it "does not ask the referential about an invalid designation" do
      expect(API::HubAPI::Organizations).not_to receive(:verify)

      result = described_class.call(form: validated_form(siret: "123"))

      expect(result).to be_success
      expect(result.refusals).to be_nil
    end
  end
end
