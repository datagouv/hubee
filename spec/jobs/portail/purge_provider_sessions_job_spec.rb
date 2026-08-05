# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::PurgeProviderSessionsJob do
  describe "#perform" do
    # Le job ne ramasse que les orphelines : une session expirée est détruite dès la
    # requête suivante de son propriétaire. Restent celles dont personne n'est revenu.
    it "reaps what no browser will come back for, and spares the rest" do
      stale_denial = create(:provider_session, :denied, created_at: 16.minutes.ago)
      idle = create(:provider_session, updated_at: 31.minutes.ago)
      exhausted = create(:provider_session, created_at: 13.hours.ago)
      fresh_denial = create(:provider_session, :denied)
      live = create(:provider_session)

      described_class.perform_now

      expect(ProviderSession.all).to contain_exactly(fresh_denial, live)
      expect(ProviderSession.where(id: [stale_denial, idle, exhausted])).to be_empty
    end
  end
end
