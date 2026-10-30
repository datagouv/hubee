# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::Agents::Create::ValidatePayload do
  describe ".call" do
    # Les motifs du payload s'accumulent avec ceux des vérifications suivantes : rien ne s'arrête ici.
    it "lays the reasons on the form without failing" do
      form = build(:api_internal_agent_form, email: "", role: nil)

      result = described_class.call(form:)

      expect(result).to be_success
      expect(form.errors.details).to eq(email: [{error: :blank}], role: [{error: :blank}])
    end

    it "leaves a valid form without reason" do
      form = build(:api_internal_agent_form)

      expect(described_class.call(form:)).to be_success
      expect(form.errors).to be_empty
    end
  end
end
