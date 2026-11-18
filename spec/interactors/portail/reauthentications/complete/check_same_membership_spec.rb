# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Reauthentications::Complete::CheckSameMembership do
  let(:provider_session) { create(:provider_session) }

  it "passes when ProConnect authenticated the session's membership" do
    expect(described_class.call(provider_session:, membership: provider_session.membership)).to be_success
  end

  it "fails as a mismatch on any other membership" do
    result = described_class.call(provider_session:, membership: create(:membership))

    expect(result.error).to eq(:reauthentication_mismatch)
  end
end
