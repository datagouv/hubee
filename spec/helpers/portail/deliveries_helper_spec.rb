# frozen_string_literal: true

require "rails_helper"

# Le contrat d'affichage des CHAMPS se teste ici plutôt que dans les gabarits : c'est le helper
# qui le porte, et les vues n'ont plus qu'à appeler. Éprouvé sur les deux formes de démarche —
# la liste et le détail — parce que c'est cette parité que le helper achète. L'historique et la
# navigation ont leur propre helper, et leur propre spec.
RSpec.describe Portail::DeliveriesHelper, type: :helper do
  describe "#delivery_state" do
    # Deux états, deux libellés : une traduction figée sur une seule valeur passerait ce test
    # avec un libellé codé en dur.
    it "translates each state into its own French label" do
      expect(helper.delivery_state(build(:portail_delivery, state: "acknowledged"))).to eq("Reçue")
      expect(helper.delivery_state(build(:portail_delivery, state: "done"))).to eq("Traitée")
    end

    # La liste des états appartient à l'amont, qui peut en ajouter un sans nous prévenir. Sans
    # repli, l'agent lirait « translation missing » en clair dans le tableau.
    it "falls back to a dash for a state the upstream added without us" do
      expect(helper.delivery_state(build(:portail_delivery, state: "inconnu"))).to eq("—")
    end
  end

  describe "#delivery_transmitted_at and #delivery_updated_at" do
    # En entier, et non abrégé : sans l'année ni le jour de la semaine, une date de
    # transmission relue plusieurs semaines après ne situe plus rien. Deux dates distinctes :
    # chaque champ doit rendre la sienne, pas une valeur partagée par accident.
    it "writes each date in full" do
      delivery = build(:portail_delivery,
        transmitted_at: Time.zone.local(2026, 8, 20, 14, 30),
        updated_at: Time.zone.local(2026, 9, 1, 9, 5))

      expect(helper.delivery_transmitted_at(delivery)).to eq("jeudi 20 août 2026 14h30")
      expect(helper.delivery_updated_at(delivery)).to eq("mardi 01 septembre 2026 09h05")
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

    # Un demandeur présent mais aux deux moitiés vides est servi par l'amont : il tombe sur le
    # même repli qu'un demandeur absent — jamais sur une ligne vide.
    it "falls back to a dash when the applicant carries no name at all" do
      applicant = build(:portail_applicant, first_name: nil, last_name: "")

      expect(helper.delivery_applicant(build(:portail_delivery, applicant: applicant))).to eq("—")
    end
  end

  describe "#delivery_state_badge" do
    # Deux états, deux couleurs : une table qui rendrait toujours la même classe passerait un
    # test à une seule valeur.
    it "colours each badge from its own state" do
      done = helper.delivery_state_badge(build(:portail_delivery, state: "done"))
      refused = helper.delivery_state_badge(build(:portail_delivery, state: "refused"))

      expect(Capybara.string(done)).to have_css("p.fr-badge.fr-badge--success", text: "Traitée")
      expect(Capybara.string(refused)).to have_css("p.fr-badge.fr-badge--error", text: "Refusée")
    end

    # Une démarche clôturée n'est ni un succès ni un échec : le badge reste neutre, et c'est
    # une décision, pas un oubli de couleur.
    it "leaves a closed delivery neutral" do
      badge = helper.delivery_state_badge(build(:portail_delivery, state: "closed"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "Clôturée")
      expect(badge).not_to include("fr-badge--")
    end

    # Même doctrine que le libellé : un état ajouté en amont sans nous prévenir ne doit pas
    # faire tomber le détail entier faute d'une couleur.
    it "falls back to a neutral badge for a state the upstream added without us" do
      badge = helper.delivery_state_badge(build(:portail_delivery, state: "inconnu"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "—")
    end
  end

  describe "#delivery_attachment_state" do
    it "colours each badge from its own attachment state" do
      rejected = helper.delivery_attachment_state(build(:portail_attachment, state: "rejected"))
      received = helper.delivery_attachment_state(build(:portail_attachment, state: "received"))

      expect(Capybara.string(rejected)).to have_css("p.fr-badge.fr-badge--error", text: "Rejetée")
      expect(Capybara.string(received)).to have_css("p.fr-badge.fr-badge--success", text: "Reçue")
    end

    it "falls back to a dash for a state the upstream added without us" do
      badge = helper.delivery_attachment_state(build(:portail_attachment, state: "inconnu"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "—")
    end
  end

  describe "#delivery_attachment_size" do
    # Deux ordres de grandeur : c'est l'unité qui doit changer, pas seulement le nombre.
    it "renders the size in human units" do
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: 2048)))
        .to eq("2 ko")
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: 3_145_728)))
        .to eq("3 Mo")
    end

    # La taille est déclarative tant que la pièce n'est pas reçue, et l'amont peut ne pas la
    # servir du tout : même repli que les dates.
    it "falls back to a dash when the upstream serves no size" do
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: nil)))
        .to eq("—")
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
