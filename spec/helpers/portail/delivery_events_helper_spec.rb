# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::DeliveryEventsHelper, type: :helper do
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

    # Les deux frontières d'un mois tombent dans le même groupe : c'est le mois qui groupe,
    # pas une fenêtre glissante autour de chaque event.
    it "groups both ends of a month together" do
      opening = build(:portail_event, id: "first-day", created_at: Time.zone.local(2026, 1, 1, 0, 0))
      closing = build(:portail_event, id: "last-day", created_at: Time.zone.local(2026, 1, 31, 23, 59))
      delivery = build(:portail_delivery, events: [opening, closing])

      groups = helper.delivery_events_by_month(delivery)

      expect(groups.keys).to eq([Time.zone.local(2026, 1, 1)])
      expect(groups.values.first.map(&:id)).to eq(["last-day", "first-day"])
    end
  end

  describe "#delivery_event_month" do
    # Deux mois, dont un accentué : la capitale doit tenir aussi sur une initiale non ASCII.
    it "titles the group with its own month, capitalised" do
      expect(helper.delivery_event_month(Time.zone.local(2026, 1, 1))).to eq("Janvier 2026")
      expect(helper.delivery_event_month(Time.zone.local(2026, 8, 1))).to eq("Août 2026")
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
    # instruction étalée sur plusieurs jours. Deux jours distincts : la capitale et le jour
    # doivent venir de la date, pas d'un libellé figé.
    it "situates each event with its own weekday" do
      saturday = build(:portail_event, created_at: Time.zone.local(2026, 1, 10, 16, 16))
      monday = build(:portail_event, created_at: Time.zone.local(2026, 1, 12, 8, 5))

      expect(helper.delivery_event_time(saturday)).to eq("Samedi 10/01 - 16:16")
      expect(helper.delivery_event_time(monday)).to eq("Lundi 12/01 - 08:05")
    end

    it "falls back to a dash for an event the upstream left undated" do
      expect(helper.delivery_event_time(build(:portail_event, created_at: nil))).to eq("—")
    end
  end
end
