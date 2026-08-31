# frozen_string_literal: true

require "rails_helper"

# Le contrat d'affichage se teste ici plutôt que dans les gabarits : c'est le helper qui le
# porte, et les vues n'ont plus qu'à appeler. Éprouvé sur les deux formes de démarche — la
# liste et le détail — parce que c'est cette parité que le helper achète.
RSpec.describe Portail::DeliveriesHelper, type: :helper do
  describe "#delivery_state" do
    it "translates the state into its French label" do
      expect(helper.delivery_state(build(:portail_delivery, state: "acknowledged"))).to eq("Reçue")
    end

    # La liste des états appartient à l'amont, qui peut en ajouter un sans nous prévenir. Sans
    # repli, l'agent lirait « translation missing » en clair dans le tableau.
    it "falls back to a dash for a state the upstream added without us" do
      expect(helper.delivery_state(build(:portail_delivery, state: "inconnu"))).to eq("—")
    end
  end

  describe "#delivery_transmitted_at and #delivery_updated_at" do
    it "formats both dates" do
      delivery = build(:portail_delivery, transmitted_at: Time.zone.local(2026, 8, 20, 14, 30))

      expect(helper.delivery_transmitted_at(delivery))
        .to eq(I18n.l(delivery.transmitted_at, format: :short))
    end

    # Les champs que l'amont peut ne pas servir tombent tous sur le même repli — c'est ce qui
    # évite qu'un écran se mette à masquer une ligne là où un autre affiche un tiret.
    it "falls back to a dash for every date the upstream may leave empty" do
      delivery = build(:portail_delivery, transmitted_at: nil, updated_at: nil)

      expect(helper.delivery_transmitted_at(delivery)).to eq("—")
      expect(helper.delivery_updated_at(delivery)).to eq("—")
    end
  end

  describe "#delivery_applicant" do
    it "renders the applicant full name when the upstream serves one" do
      expect(helper.delivery_applicant(build(:portail_delivery))).to eq("George DUBOIS")
    end

    it "falls back to a dash when the upstream serves no applicant" do
      expect(helper.delivery_applicant(build(:portail_delivery, applicant: nil))).to eq("—")
    end
  end

  describe "#delivery_pagination_pages" do
    it "lists every page while they all fit" do
      pagination = build(:portail_pagination, current_page: 2, total_pages: 4)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, 2, 3, 4])
    end

    # Une liste de plusieurs centaines de pages ferait un pied plus long que le tableau : on
    # garde les extrémités, la page courante et ses voisines, et on marque les trous.
    it "keeps the ends and the current neighbourhood, and marks the gaps" do
      pagination = build(:portail_pagination, current_page: 20, total_pages: 40)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, :gap, 19, 20, 21, :gap, 40])
    end

    # Aux extrémités, il n'y a qu'un seul trou : une ellipse de part et d'autre suggérerait des
    # pages qui n'existent pas.
    it "opens no gap where the neighbourhood already touches an end" do
      pagination = build(:portail_pagination, current_page: 2, total_pages: 40)

      expect(helper.delivery_pagination_pages(pagination)).to eq([1, 2, 3, :gap, 40])
    end
  end

  # La forme liste et la forme détail portent les mêmes champs communs : une seule fonction
  # sert les deux, donc il n'y a plus rien qui puisse diverger. Cet exemple le constate.
  it "serves the list form exactly like the detail form" do
    summary = build(:portail_delivery_summary, state: "transmitted", transmitted_at: nil)

    expect(helper.delivery_state(summary)).to eq("Transmise")
    expect(helper.delivery_transmitted_at(summary)).to eq("—")
  end
end
