# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::SecondFactor do
  before { stub_const("Portail::SensitiveProcesses::CODES", %w[SGR]) }

  def membership_with(process_code, *traits)
    create(:membership, *traits).tap do |membership|
      create(:process_access, membership:, process_code:) if process_code
    end
  end

  describe ".required_for?" do
    it "spares an ordinary agent who touches no sensitive process" do
      expect(described_class.required_for?(membership_with(nil))).to be(false)
      expect(described_class.required_for?(membership_with("AEC"))).to be(false)
    end

    it "requires it of a local administrator, whatever their processes" do
      expect(described_class.required_for?(membership_with(nil, :local_administrator)))
        .to be(true)
    end

    it "requires it of an ordinary agent holding a sensitive process" do
      expect(described_class.required_for?(membership_with("SGR"))).to be(true)
    end

    # Les codes sont stockés verbatim : sans comparaison insensible à la casse, cet agent
    # échapperait au second facteur sans qu'aucune erreur ne le signale.
    it "requires it however the sensitive code is spelled" do
      expect(described_class.required_for?(membership_with("sgr"))).to be(true)
    end
  end

  describe ".satisfied?" do
    it "lets any level through for a membership that owes no second factor" do
      session = create(:provider_session, membership: membership_with(nil), acr: "eidas1")

      expect(described_class.satisfied?(session)).to be(true)
    end

    it "accepts only the levels that attest a second factor" do
      membership = membership_with(nil, :local_administrator)

      expect(described_class.satisfied?(create(:provider_session, membership:, acr: "eidas1")))
        .to be(false)
      expect(described_class.satisfied?(create(:provider_session, membership:, acr: "eidas1-mfa")))
        .to be(true)
      expect(described_class.satisfied?(create(:provider_session, membership:, acr: "eidas2")))
        .to be(true)
    end
  end
end
