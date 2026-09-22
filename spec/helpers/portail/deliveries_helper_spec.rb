# frozen_string_literal: true

require "rails_helper"

# Le contrat d'affichage des champs, éprouvé sur la liste et le détail : c'est cette parité
# que le helper achète.
RSpec.describe Portail::DeliveriesHelper, type: :helper do
  describe "#delivery_state" do
    # Deux états : un libellé codé en dur passerait un test à une seule valeur.
    it "translates each state into its own French label" do
      expect(helper.delivery_state(build(:portail_delivery, state: "acknowledged"))).to eq("Reçu")
      expect(helper.delivery_state(build(:portail_delivery, state: "done"))).to eq("Traité")
    end

    it "falls back to a dash for a state the upstream added without us" do
      expect(helper.delivery_state(build(:portail_delivery, state: "inconnu"))).to eq("—")
    end
  end

  describe "#delivery_state_label" do
    # Sans ce repli, I18n résout la clé tronquée vers son parent : le Hash entier des libellés.
    it "falls back to a dash for a missing state" do
      expect(helper.delivery_state_label(nil)).to eq("—")
      expect(helper.delivery_state_label("")).to eq("—")
    end

    # Supervisé par HubEE : l'état n'a pas de libellé sur le portail, seulement le repli neutre.
    it "falls back to a dash for the hidden integration error state" do
      expect(helper.delivery_state_label("integration_error")).to eq("—")
    end
  end

  describe "#delivery_transmitted_at and #delivery_updated_at" do
    # Deux dates distinctes : chaque champ doit rendre la sienne.
    it "writes each date in full" do
      delivery = build(:portail_delivery,
        transmitted_at: Time.zone.local(2026, 8, 20, 14, 30),
        updated_at: Time.zone.local(2026, 9, 1, 9, 5))

      expect(helper.delivery_transmitted_at(delivery)).to eq("jeudi 20 août 2026 14h30")
      expect(helper.delivery_updated_at(delivery)).to eq("mardi 01 septembre 2026 09h05")
    end

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

    # Un demandeur présent mais vide tombe sur le même repli qu'un demandeur absent.
    it "falls back to a dash when the applicant carries no name at all" do
      applicant = build(:portail_applicant, first_name: nil, last_name: "")

      expect(helper.delivery_applicant(build(:portail_delivery, applicant: applicant))).to eq("—")
    end
  end

  describe "#data_stream_label" do
    # Le libellé identifie la démarche, le code reste : c'est lui qui sert au support.
    it "names the data stream from the names known, code kept after a dash" do
      names = {"CERTDC" => "Certificat de décès électronique"}

      expect(helper.data_stream_label("CERTDC", names)).to eq("Certificat de décès électronique – CERTDC")
    end

    # Un flux sans intitulé connu, ou des intitulés indisponibles : la ligne reste identifiable.
    # Un intitulé blanc n'arrive jamais ici, la liste d'abonnements ne le projette pas.
    it "falls back to the code alone when no name is known for it" do
      expect(helper.data_stream_label("AEC", {"CERTDC" => "Certificat de décès électronique"})).to eq("AEC")
      expect(helper.data_stream_label("AEC", {})).to eq("AEC")
    end
  end

  describe "#delivery_state_badge" do
    it "colours each badge from its own state" do
      done = helper.delivery_state_badge(build(:portail_delivery, state: "done"))
      refused = helper.delivery_state_badge(build(:portail_delivery, state: "refused"))

      expect(Capybara.string(done)).to have_css("p.fr-badge.fr-badge--success", text: "Traité")
      expect(Capybara.string(refused)).to have_css("p.fr-badge.fr-badge--error", text: "Refusé")
    end

    # Neutre par décision, pas par oubli.
    it "leaves a closed delivery neutral" do
      badge = helper.delivery_state_badge(build(:portail_delivery, state: "closed"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "Clos")
      expect(badge).not_to include("fr-badge--")
    end

    it "falls back to a neutral badge for a state the upstream added without us" do
      badge = helper.delivery_state_badge(build(:portail_delivery, state: "inconnu"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "—")
    end

    # Le détail d'un télédossier ouverte par son URL dans cet état tombe sur le même repli.
    it "falls back to a neutral badge for the hidden integration error state" do
      badge = helper.delivery_state_badge(build(:portail_delivery, state: "integration_error"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "—")
      expect(badge).not_to include("fr-badge--")
    end
  end

  describe "#delivery_attachment_access" do
    let(:delivery) { build(:portail_delivery, id: "94b1b09d-b47f-4480-9b48-93b8b36108f2") }

    # Le seul cas qui remet un contenu : une pièce reçue, portée par un télédossier. Le bouton est
    # l'affordance, sans badge à côté ; RGAA : le nom accessible porte la pièce.
    it "links to the download of a received deposit piece, named after the piece" do
      link = helper.delivery_attachment_access(build(:portail_attachment, filename: "recue.pdf"), delivery)

      page = Capybara.string(link)
      expect(page).to have_link("Télécharger",
        href: "/teledossiers/94b1b09d-b47f-4480-9b48-93b8b36108f2/pieces/a1111111-1111-1111-1111-111111111111")
      expect(page).to have_css("a.fr-btn.fr-btn--sm[data-turbo='false'][aria-label='Télécharger recue.pdf']")
      expect(page).to have_no_css("p.fr-badge")
      # Surtout pas `download` : le navigateur enregistrerait la réponse quelle qu'elle soit, et
      # une page d'erreur finirait en fichier HTML sur le disque de l'agent.
      expect(page).to have_no_css("a[download]")
    end

    # RGAA : sans ça, le nom accessible du lien s'arrête à « Télécharger », identique à celui de
    # toutes les autres pièces. Le repli est celui du fichier remis et de la trace.
    it "names a piece the partner did not name after the shared fallback" do
      link = helper.delivery_attachment_access(build(:portail_attachment, filename: ""), delivery)

      expect(Capybara.string(link)).to have_css("a[aria-label='Télécharger piece']")
    end

    it "shows the state of a deposit piece that is not received, as the reason" do
      badge = helper.delivery_attachment_access(build(:portail_attachment, state: "corrupted"), delivery)

      expect(Capybara.string(badge)).to have_css("p.fr-badge.fr-badge--sm.fr-badge--error", text: "Corrompue")
      expect(Capybara.string(badge)).to have_no_link
    end

    # Une pièce d'événement n'a pas d'adresse : reçue ou non, seul son état se montre.
    it "shows only the state of a piece without a delivery to download it from" do
      badge = helper.delivery_attachment_access(build(:portail_attachment), nil)

      expect(Capybara.string(badge)).to have_css("p.fr-badge.fr-badge--success", text: "Reçue")
      expect(Capybara.string(badge)).to have_no_link
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
    # Deux ordres de grandeur : c'est l'unité qui doit changer.
    it "renders the size in human units" do
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: 2048)))
        .to eq("2 ko")
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: 3_145_728)))
        .to eq("3 Mo")
    end

    it "falls back to a dash when the upstream serves no size" do
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: nil)))
        .to eq("—")
    end
  end

  it "serves the list form exactly like the detail form" do
    summary = build(:portail_delivery_summary, state: "transmitted", transmitted_at: nil)

    expect(helper.delivery_state(summary)).to eq("Nouveau")
    expect(helper.delivery_transmitted_at(summary)).to eq("—")
  end
end
