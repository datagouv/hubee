# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery do
  # Le contrat d'affichage se teste ici plutôt que dans les gabarits : c'est le modèle qui le
  # porte, et les vues n'ont plus qu'à appeler.
  describe "display methods" do
    it "translates the state and formats both dates" do
      delivery = build(:portail_delivery, state: "acknowledged",
        transmitted_at: Time.zone.local(2026, 8, 20, 14, 30))

      expect(delivery.display_state).to eq("Reçue")
      expect(delivery.display_transmitted_at).to eq(I18n.l(delivery.transmitted_at, format: :short))
    end

    # Les champs que l'amont peut ne pas servir tombent tous sur le même repli — c'est ce qui
    # évite qu'un écran se mette à masquer une ligne là où un autre affiche un tiret.
    it "falls back to a dash for every field the upstream may leave empty" do
      delivery = build(:portail_delivery, transmitted_at: nil, updated_at: nil, applicant: nil)

      expect(delivery.display_transmitted_at).to eq("—")
      expect(delivery.display_updated_at).to eq("—")
      expect(delivery.display_applicant).to eq("—")
    end

    it "renders the applicant full name when the upstream serves one" do
      expect(build(:portail_delivery).display_applicant).to eq("George DUBOIS")
    end
  end
end
