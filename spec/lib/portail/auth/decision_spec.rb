# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Auth::Decision do
  describe "#to_h" do
    it "carries the decision and what it was based on" do
      decision = described_class.new(outcome: :denied, reason: :organization_mismatch,
        email: "agent@example.gouv.fr", siret: "13002526500013", acr: "eidas1")

      expect(decision.to_h).to include(outcome: :denied, reason: :organization_mismatch,
        email: "agent@example.gouv.fr", siret: "13002526500013", acr: "eidas1")
    end

    # L'invariant le plus coûteux à violer : un jeton dans une table conservée six mois.
    # Le Data ferme le jeu de clés ; cet exemple épingle lesquelles.
    # Le persisteur fait `AccessDecision.create!(**decision.to_h)` : un champ ajouté ici et
    # pas en base ferait échouer l'écriture en production, sans rien casser en amont.
    it "names only fields the audit table can hold" do
      expect(AccessDecision.column_names).to include(*described_class.members.map(&:to_s))
    end

    it "carries these fields and no others" do
      expect(described_class.new(outcome: :granted).to_h.keys).to contain_exactly(
        :outcome, :reason, :email, :provider_sub, :siret, :organization_label, :idp_id,
        :acr, :amr, :agent_id, :membership_id, :provider_sub_changed
      )
    end
  end
end
