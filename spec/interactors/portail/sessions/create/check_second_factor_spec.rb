# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Sessions::Create::CheckSecondFactor do
  subject(:result) { described_class.call(membership:, claims: {acr:, amr:}, step_up_attempted:) }

  let(:step_up_attempted) { nil }
  let(:amr) { ["pwd"] }

  context "when the membership owes no second factor" do
    let(:membership) { create(:membership) }
    let(:acr) { "eidas1" }

    it "lets the session through" do
      expect(result).to be_success
    end
  end

  context "when the membership owes one" do
    let(:membership) { create(:membership, :local_administrator) }

    context "and the level attests it" do
      let(:acr) { "eidas1-mfa" }

      it "lets the session through" do
        expect(result).to be_success
      end
    end

    # Le FI a imposé sa propre MFA sans être qualifié pour l'attester en niveau : l'acr
    # reste eidas1, l'amr en témoigne — rien à élever.
    context "and the identity provider already imposed a second factor" do
      let(:acr) { "eidas1" }
      let(:amr) { ["pwd", "mfa"] }

      it "lets the session through without a step-up" do
        expect(result).to be_success
      end
    end

    context "and the level does not" do
      let(:acr) { "eidas1" }

      # Première tentative : on élève plutôt que de refuser, ProConnect sachant fournir le
      # second facteur même quand le fournisseur d'identité ne le sait pas.
      it "asks for a step-up" do
        expect(result).to be_failure
        expect(result.error).to eq(:step_up_required)
      end

      context "after a step-up already went through" do
        let(:step_up_attempted) { true }

        # Redemander enverrait l'agent en boucle entre les deux services.
        it "refuses instead of asking again" do
          expect(result).to be_failure
          expect(result.error).to eq(:second_factor_required)
        end
      end
    end
  end
end
