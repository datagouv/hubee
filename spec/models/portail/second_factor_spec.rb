# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::SecondFactor do
  # Code inventé : la vraie liste vient de l'outillage de déploiement et ne descend pas dans
  # ce dépôt, qui est public. La règle testée ne dépend d'aucune valeur en particulier.
  before { stub_const("Portail::SensitiveProcesses::CODES", %w[DEMO_SENSIBLE]) }

  def membership_with(process_code, *traits)
    create(:membership, *traits).tap do |membership|
      create(:process_access, membership:, process_code:) if process_code
    end
  end

  describe ".required_for?" do
    it "spares an ordinary agent who touches no sensitive process" do
      expect(described_class.required_for?(membership_with(nil))).to be(false)
      expect(described_class.required_for?(membership_with("DEMO_ORDINAIRE"))).to be(false)
    end

    it "requires it of a local administrator, whatever their processes" do
      expect(described_class.required_for?(membership_with(nil, :local_administrator)))
        .to be(true)
    end

    it "requires it of an ordinary agent holding a sensitive process" do
      expect(described_class.required_for?(membership_with("DEMO_SENSIBLE"))).to be(true)
    end

    # Les codes sont stockés verbatim : sans comparaison insensible à la casse, cet agent
    # échapperait au second facteur sans qu'aucune erreur ne le signale.
    it "requires it however the sensitive code is spelled" do
      expect(described_class.required_for?(membership_with("demo_sensible"))).to be(true)
    end
  end

  describe ".satisfied?" do
    it "lets any level through for a membership that owes no second factor" do
      expect(described_class.satisfied?(membership_with(nil), acr: "eidas1")).to be(true)
    end

    it "accepts the levels that attest a second factor" do
      membership = membership_with(nil, :local_administrator)

      expect(described_class.satisfied?(membership, acr: "eidas1")).to be(false)
      expect(described_class.satisfied?(membership, acr: "eidas1-mfa")).to be(true)
      expect(described_class.satisfied?(membership, acr: "eidas2")).to be(true)
    end

    # Certains fournisseurs d'identité imposent leur propre MFA sans être qualifiés pour
    # l'attester en niveau : l'acr reste eidas1, l'amr du jeton vérifié en témoigne.
    it "accepts a second factor the identity provider imposed on its own" do
      membership = membership_with(nil, :local_administrator)

      expect(described_class.satisfied?(membership, acr: "eidas1", amr: ["pwd", "mfa"])).to be(true)
      expect(described_class.satisfied?(membership, acr: "eidas1", amr: ["pwd"])).to be(false)
    end
  end
end
