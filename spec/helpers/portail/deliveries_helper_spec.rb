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
    # En entier, et non abrégé : sans l'année ni le jour de la semaine, une date de
    # transmission relue plusieurs semaines après ne situe plus rien.
    it "writes both dates in full" do
      delivery = build(:portail_delivery, transmitted_at: Time.zone.local(2026, 8, 20, 14, 30))

      expect(helper.delivery_transmitted_at(delivery))
        .to eq("jeudi 20 août 2026 14h30")
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

  describe "#delivery_state_badge" do
    it "colours the badge from the state" do
      badge = helper.delivery_state_badge(build(:portail_delivery, state: "done"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge.fr-badge--success", text: "Traitée")
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

  describe "#delivery_state_menu_link" do
    it "links to the state and carries its count" do
      link = helper.delivery_state_menu_link("acknowledged", 12, current: false)

      expect(Capybara.string(link)).to have_link("Reçue 12", href: "/demarches?statut=acknowledged")
    end

    # DSFR marque l'entrée active par `aria-current`, pas par une classe : c'est cet attribut
    # qui porte à la fois le rendu et l'annonce aux technologies d'assistance.
    it "marks the active state as the current page" do
      link = helper.delivery_state_menu_link("acknowledged", 12, current: true)

      expect(Capybara.string(link)).to have_css("a.fr-sidemenu__link[aria-current='page']")
    end

    it "leaves aria-current out entirely on the other states" do
      link = helper.delivery_state_menu_link("acknowledged", 12, current: false)

      expect(link).not_to include("aria-current")
    end
  end

  describe "#delivery_attachment_state" do
    it "colours the badge from the attachment state" do
      badge = helper.delivery_attachment_state(build(:portail_attachment, state: "rejected"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge.fr-badge--error", text: "Rejetée")
    end

    it "falls back to a dash for a state the upstream added without us" do
      badge = helper.delivery_attachment_state(build(:portail_attachment, state: "inconnu"))

      expect(Capybara.string(badge)).to have_css("p.fr-badge", text: "—")
    end
  end

  describe "#delivery_attachment_size" do
    it "renders the size in human units" do
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: 2048)))
        .to eq("2 ko")
    end

    # La taille est déclarative tant que la pièce n'est pas reçue, et l'amont peut ne pas la
    # servir du tout : même repli que les dates.
    it "falls back to a dash when the upstream serves no size" do
      expect(helper.delivery_attachment_size(build(:portail_attachment, byte_size: nil)))
        .to eq("—")
    end
  end

  describe "#delivery_events_with_attachments" do
    it "keeps only the events that brought a piece" do
      carrying = build(:portail_event, id: "with", attachments: [build(:portail_attachment)])
      bare = build(:portail_event, id: "without", attachments: [])
      delivery = build(:portail_delivery, events: [carrying, bare])

      expect(helper.delivery_events_with_attachments(delivery).map(&:id)).to eq(["with"])
    end
  end

  describe "#delivery_events_by_month" do
    # Du plus récent au plus ancien, alors que la gem trie dans l'autre sens : ce qu'on vient
    # chercher en ouvrant un historique, c'est ce qui s'est passé en dernier.
    it "opens on the most recent month and works backwards" do
      january = build(:portail_event, id: "jan", created_at: Time.zone.local(2026, 1, 10, 16, 16))
      february = build(:portail_event, id: "feb", created_at: Time.zone.local(2026, 2, 3, 9, 0))
      delivery = build(:portail_delivery, events: [january, february])

      groups = helper.delivery_events_by_month(delivery)

      expect(groups.values.map { |events| events.map(&:id) }).to eq([["feb"], ["jan"]])
    end

    it "reverses the entries inside a month too" do
      first = build(:portail_event, id: "first", created_at: Time.zone.local(2026, 1, 10, 9, 0))
      last = build(:portail_event, id: "last", created_at: Time.zone.local(2026, 1, 10, 16, 16))
      delivery = build(:portail_delivery, events: [first, last])

      groups = helper.delivery_events_by_month(delivery)

      expect(groups.values.first.map(&:id)).to eq(["last", "first"])
    end

    # La gem range les events sans date en fin de liste : ils forment un dernier groupe, que le
    # gabarit intitule à part. Les jeter serait perdre une ligne d'historique.
    #
    # Et ils ne suivent PAS l'inversion : les faire remonter en tête au seul motif qu'on
    # renverse la liste les présenterait comme les plus récents, ce que personne ne sait.
    it "keeps the undated events last, out of the reversal" do
      dated = build(:portail_event, id: "dated", created_at: Time.zone.local(2026, 1, 10))
      undated = build(:portail_event, id: "undated", created_at: nil)
      delivery = build(:portail_delivery, events: [dated, undated])

      groups = helper.delivery_events_by_month(delivery)

      expect(groups[nil].map(&:id)).to eq(["undated"])
      expect(groups.keys.last).to be_nil
    end
  end

  describe "#delivery_event_month" do
    it "titles the group with the month, capitalised" do
      expect(helper.delivery_event_month(Time.zone.local(2026, 1, 1))).to eq("Janvier 2026")
    end

    it "names the group of events the upstream left undated" do
      expect(helper.delivery_event_month(nil)).to eq("Sans date")
    end
  end

  describe "#delivery_event_sentence" do
    it "names both ends of a state change, and who made it" do
      event = build(:portail_event, event_type: "delivery.state_changed", author: "George DUBOIS",
        metadata: {from_state: "transmitted", to_state: "done"})

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to eq("George DUBOIS a modifié le statut : Transmise → Traitée")
    end

    # L'auteur vient de l'amont : il est mis en gras, donc interpolé dans une clé `_html`, et
    # doit ressortir échappé. Sans quoi un nom porteur de balises s'exécuterait dans la page.
    it "escapes the author rather than trusting the upstream" do
      event = build(:portail_event, author: "<script>alert(1)</script>")

      expect(helper.delivery_event_sentence(event)).not_to include("<script>")
    end

    it "falls back to an impersonal actor when the upstream names none" do
      event = build(:portail_event, author: nil)

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to start_with("Un auteur inconnu")
    end

    # Le type seul ne distingue pas un téléchargement unitaire d'un téléchargement en masse :
    # seule la metadata le dit, et l'agent n'a pas à confondre les deux.
    it "tells a bulk download from a single one" do
      single = build(:portail_event, event_type: "attachment.downloaded", metadata: {})
      bulk = build(:portail_event, event_type: "attachment.downloaded", metadata: {bulk: true})

      expect(Capybara.string(helper.delivery_event_sentence(single)).text)
        .to end_with("a téléchargé une pièce")
      expect(Capybara.string(helper.delivery_event_sentence(bulk)).text)
        .to end_with("a téléchargé toutes les pièces")
    end

    it "tells a sent message from an internal comment" do
      sent = build(:portail_event, event_type: "message.created", metadata: {internal: false})
      internal = build(:portail_event, event_type: "message.created", metadata: {internal: true})

      expect(Capybara.string(helper.delivery_event_sentence(sent)).text)
        .to end_with("a envoyé un message")
      expect(Capybara.string(helper.delivery_event_sentence(internal)).text)
        .to end_with("a ajouté un commentaire interne")
    end

    it "names a deposited attachment" do
      event = build(:portail_event, event_type: "attachment.created", metadata: {})

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to end_with("a déposé une pièce")
    end

    # L'amont peut ajouter un type sans nous prévenir, et il sert déjà `unknown` de lui-même
    # quand il ne sait pas qualifier une ligne. Une ligne datée sans phrase précise vaut mieux
    # qu'une page qui tombe.
    it "keeps an event the upstream could not qualify" do
      event = build(:portail_event, event_type: "unknown", metadata: {})

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to end_with("est intervenu sur la démarche")
    end
  end

  describe "#delivery_event_broadcast?" do
    # `== false` et non `!` : une clé absente ne veut pas dire « diffusé ». Un changement
    # d'état n'a rien promis à personne, et l'annoncer serait un mensonge à l'agent.
    it "only marks what the upstream says left the hub" do
      sent = build(:portail_event, metadata: {internal: false})
      internal = build(:portail_event, metadata: {internal: true})
      state_change = build(:portail_event, metadata: {from_state: "transmitted"})

      expect(helper.delivery_event_broadcast?(sent)).to be(true)
      expect(helper.delivery_event_broadcast?(internal)).to be(false)
      expect(helper.delivery_event_broadcast?(state_change)).to be(false)
    end
  end

  describe "#delivery_event_time" do
    # Le jour de la semaine situe l'événement bien mieux qu'une date seule quand on relit une
    # instruction étalée sur plusieurs jours.
    it "situates the event with its weekday" do
      event = build(:portail_event, created_at: Time.zone.local(2026, 1, 10, 16, 16))

      expect(helper.delivery_event_time(event)).to eq("Samedi 10/01 - 16:16")
    end

    it "falls back to a dash for an event the upstream left undated" do
      expect(helper.delivery_event_time(build(:portail_event, created_at: nil))).to eq("—")
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
