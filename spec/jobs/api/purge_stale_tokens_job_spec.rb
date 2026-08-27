# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::PurgeStaleTokensJob do
  describe "#perform" do
    it "deletes revoked and expired tokens, and spares the live ones" do
      revoked = create(:oauth_access_token)
      revoked.revoke
      expired = travel_to(3.hours.ago) { create(:oauth_access_token) }
      live = create(:oauth_access_token)

      described_class.perform_now

      expect(Doorkeeper::AccessToken.all).to contain_exactly(live)
      expect(Doorkeeper::AccessToken.where(id: [revoked.id, expired.id])).to be_empty
    end
  end
end
