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
    # Le libellé identifie le flux, le code reste : c'est lui qui sert au support.
    it "names the data stream, code kept after a dash" do
      expect(helper.data_stream_label("CERTDC", "Certificat de décès électronique"))
        .to eq("Certificat de décès électronique – CERTDC")
    end

    # Un flux sans nom connu, ou un flux qui ne se lit pas : la ligne reste identifiable. Un nom
    # blanc n'arrive jamais ici, la liste d'abonnements ne le projette pas.
    it "falls back to the code alone when no name is known" do
      expect(helper.data_stream_label("AEC", nil)).to eq("AEC")
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

    # Le seul cas qui remet un contenu : une pièce reçue, portée par un télédossier. Le lien est
    # l'affordance, sans badge à côté ; RGAA : le nom accessible commence par le texte visible et
    # finit par la pièce. Aucun détail : le nom du fichier dit déjà son extension, la taille a sa
    # colonne.
    it "links to the download of a received deposit piece, named after the piece" do
      link = helper.delivery_attachment_access(build(:portail_attachment, filename: "recue.pdf"), delivery)

      page = Capybara.string(link)
      expect(page).to have_link("Télécharger",
        href: "/teledossiers/94b1b09d-b47f-4480-9b48-93b8b36108f2/pieces/a1111111-1111-1111-1111-111111111111")
      expect(page).to have_link(exact_text: "Télécharger, recue.pdf")
      expect(page).to have_css("a.fr-link.fr-link--download[data-turbo='false']")
      expect(page).to have_css("a span.fr-sr-only", exact_text: ", recue.pdf")
      expect(page).to have_no_css(".fr-link__detail")
      expect(page).to have_no_css("a[aria-label]")
      expect(page).to have_no_css("a.fr-btn")
      expect(page).to have_no_css("p.fr-badge")
      # Surtout pas `download` : le navigateur enregistrerait la réponse quelle qu'elle soit, et
      # une page d'erreur finirait en fichier HTML sur le disque de l'agent.
      expect(page).to have_no_css("a[download]")
    end

    # RGAA : sans ça, le nom accessible du lien s'arrête à « Télécharger », identique à celui de
    # toutes les autres pièces. Le repli est celui du fichier remis et de la trace.
    it "names a piece the partner did not name after the shared fallback" do
      link = helper.delivery_attachment_access(build(:portail_attachment, filename: ""), delivery)

      expect(Capybara.string(link)).to have_link(exact_text: "Télécharger, piece")
    end

    # Le nom vient du partenaire : il se lit comme du texte, jamais comme du balisage.
    it "escapes the piece name in the accessible name" do
      link = helper.delivery_attachment_access(
        build(:portail_attachment, filename: "<img src=x onerror=alert(1)>.pdf"), delivery
      )

      page = Capybara.string(link)
      expect(page).to have_link(exact_text: "Télécharger, <img src=x onerror=alert(1)>.pdf")
      expect(page).to have_no_css("img")
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

  describe "#delivery_archive_access" do
    def delivery_with(*states)
      build(:portail_delivery, id: "94b1b09d-b47f-4480-9b48-93b8b36108f2",
        attachments: states.map { |state| build(:portail_attachment, state:) })
    end

    # Le compte dit ce que l'agent recevra ; le total ne s'ajoute que quand il en manque. La virgule
    # masquée sépare, pour le lecteur d'écran, le libellé du détail « ZIP ».
    it "counts the received pieces, and the total only when some are missing" do
      labels = {
        "a single received piece" => {states: %w[received], label: "Télécharger l'archive de la pièce reçue"},
        "every piece received" => {states: %w[received received], label: "Télécharger les 2 pièces reçues"},
        "one received out of three" => {states: %w[received pending corrupted],
                                        label: "Télécharger 1 pièce reçue sur 3"},
        "two received out of three" => {states: %w[received rejected received],
                                        label: "Télécharger 2 pièces reçues sur 3"}
      }

      labels.each do |name, example|
        expect(Capybara.string(helper.delivery_archive_access(delivery_with(*example[:states]))))
          .to have_link(exact_text: "#{example[:label]}, ZIP"), name
      end
    end

    # Surtout pas `download` : une page d'erreur finirait en fichier sur le disque de l'agent. Tout
    # est reçu : le détail « ZIP » suffit, aucune aide ne le répète.
    it "links a DSFR download link to the archive, outside Turbo, detailed by its format" do
      page = Capybara.string(helper.delivery_archive_access(delivery_with("received", "received")))

      expect(page).to have_link("Télécharger les 2 pièces reçues",
        href: "/teledossiers/94b1b09d-b47f-4480-9b48-93b8b36108f2/archive")
      expect(page).to have_css("a.fr-link.fr-link--download[data-turbo='false']")
      expect(page).to have_css("a span.fr-link__detail", exact_text: "ZIP")
      expect(page).to have_no_css("a[aria-describedby]")
      expect(page).to have_no_css(".fr-hint-text")
      expect(page).to have_no_css("a[download]")
      expect(page).to have_no_css("a[aria-label]")
    end

    it "warns that the pieces not received stay out of the archive" do
      page = Capybara.string(helper.delivery_archive_access(delivery_with("received", "pending")))

      expect(page).to have_css("a[aria-describedby='delivery-archive-hint']")
      expect(page).to have_css("p#delivery-archive-hint.fr-hint-text.fr-col-12",
        exact_text: "Sans les pièces non reçues : l'état de chacune figure dans le tableau.")
    end

    it "offers nothing without any received piece" do
      expect(helper.delivery_archive_access(delivery_with("pending", "corrupted", "rejected", "deleted"))).to be_nil
      expect(helper.delivery_archive_access(delivery_with)).to be_nil
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

  # La règle vit dans Access::StateTransitions, éprouvée là : ici, seulement qu'on la consulte
  # avec ce que la vue a en main.
  describe "#delivery_offered_states" do
    it "hands the table the state of the delivery and the data stream it was given" do
      data_stream = build(:portail_data_stream, :without_awaiting_attachments)

      expect(helper.delivery_offered_states(build(:portail_delivery, state: "in_progress"), data_stream))
        .to eq(%w[refused done])
    end

    it "offers the table when the data stream could not be read" do
      expect(helper.delivery_offered_states(build(:portail_delivery, state: "in_progress"), nil))
        .to eq(%w[awaiting_attachments refused done])
    end
  end

  # La table dit d'où « Reçu » s'atteint, éprouvée là : ici, qu'on la consulte flux compris.
  describe "#delivery_receipt_offered?" do
    it "offers the receipt on a new delivery" do
      expect(helper.delivery_receipt_offered?(build(:portail_delivery, state: "transmitted"), build(:portail_data_stream)))
        .to be(true)
    end

    it "does not offer the receipt on a delivery already past new" do
      expect(helper.delivery_receipt_offered?(build(:portail_delivery, state: "acknowledged"), build(:portail_data_stream)))
        .to be(false)
    end

    it "does not offer the receipt when the data stream withholds received" do
      data_stream = build(:portail_data_stream, allowed_states: %w[transmitted in_progress done])

      expect(helper.delivery_receipt_offered?(build(:portail_delivery, state: "transmitted"), data_stream))
        .to be(false)
    end
  end

  describe "#delivery_receipt_state" do
    it "names the state a receipt moves the delivery to" do
      expect(helper.delivery_receipt_state).to eq("acknowledged")
    end
  end
end
