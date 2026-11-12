# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Access::PortalPerimeter do
  def subscriptions(*subscriptions) = build(:portail_subscription_list, subscriptions:)

  describe ".covers?" do
    # Lus sur le couple du rattachement, pas sur le seul SIRET, que deux organisations peuvent
    # partager.
    it "covers the data streams the organisation of the membership receives through the portal" do
      membership = create(:membership,
        organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
      expect(Portail::HubAPI::Subscriptions).to receive(:fetch).exactly(4).times
        .with(siret: "22770001000019", insee_code: "77372")
        .and_return(subscriptions(
          build(:portail_subscription, data_stream_code: "CERTDC"),
          build(:portail_subscription, data_stream_code: "DEMO_API", access_mode: "api"),
          build(:portail_subscription, data_stream_code: "DEMO_SANS_LECTURE", read_package: false)
        ))

      expect(described_class.covers?(membership, "CERTDC")).to be(true)
      expect(described_class.covers?(membership, "DEMO_API")).to be(false)
      expect(described_class.covers?(membership, "DEMO_SANS_LECTURE")).to be(false)
      expect(described_class.covers?(membership, "AEC")).to be(false)
    end

    # Le mode d'accès inconnu, rien ne s'ouvre : une panne, que la page dit comme telle, pas un
    # refus. La frontière a déjà journalisé l'incident en rendant nil.
    it "raises an upstream unavailability when the subscriptions could not be read" do
      expect(Portail::HubAPI::Subscriptions).to receive(:fetch).and_return(nil)

      expect { described_class.covers?(create(:membership), "CERTDC") }.to raise_error(Portail::HubAPI::Unavailable)
    end
  end
end
