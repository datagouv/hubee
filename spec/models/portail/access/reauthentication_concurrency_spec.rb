# frozen_string_literal: true

require "rails_helper"

# Deux consultations envoyées ensemble avec une seule preuve : deux connexions doivent voir leurs
# écritures respectives, d'où l'absence de transaction de test englobante et le nettoyage à la main.
RSpec.describe Portail::Access::Reauthentication do
  self.use_transactional_tests = false

  after do
    [ProviderSession, Membership, Agent, OrganizationLink].each(&:delete_all)
  end

  it "lets only one of two concurrent consumptions through" do
    provider_session = create(:provider_session)
    purpose = described_class.purpose(:credentials, "subscription-a")
    described_class.record!(provider_session, purpose:, id_token: "fresh-id-token", acr: "eidas1-mfa", amr: ["mfa"])
    barrier = Concurrent::CyclicBarrier.new(2)

    results = Array.new(2) {
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          raise "barrier timed out" unless barrier.wait(5)
          described_class.consume!(ProviderSession.find(provider_session.id), purpose:)
        end
      end
    }.map(&:value)

    expect(results).to contain_exactly(true, false)
  end
end
