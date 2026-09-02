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

    # L'ordre est le nôtre, pas celui de l'amont : servis dans le désordre, les events se
    # replacent quand même.
    it "orders by date rather than trusting the upstream order" do
      newest = build(:portail_event, id: "newest", created_at: Time.zone.local(2026, 2, 3, 9, 0))
      oldest = build(:portail_event, id: "oldest", created_at: Time.zone.local(2026, 1, 10, 9, 0))
      middle = build(:portail_event, id: "middle", created_at: Time.zone.local(2026, 1, 10, 16, 16))
      delivery = build(:portail_delivery, events: [newest, oldest, middle])

      groups = helper.delivery_events_by_month(delivery)

      expect(groups.values.flatten.map(&:id)).to eq(["newest", "middle", "oldest"])
    end

    # Même seconde : l'ordre d'arrivée départage, comme la gem le fait avant nous.
    it "keeps the upstream order between events of the same instant" do
      instant = Time.zone.local(2026, 1, 10, 9, 0)
      events = %w[first second third fourth].map { |id| build(:portail_event, id: id, created_at: instant) }
      delivery = build(:portail_delivery, events: events)

      groups = helper.delivery_events_by_month(delivery)

      expect(groups.values.flatten.map(&:id)).to eq(["fourth", "third", "second", "first"])
    end

    # Les events sans date forment un dernier groupe et ne suivent pas l'inversion : remontés
    # en tête, ils passeraient pour les plus récents.
    it "keeps the undated events last, out of the reversal" do
      dated = build(:portail_event, id: "dated", created_at: Time.zone.local(2026, 1, 10))
      undated = build(:portail_event, id: "undated", created_at: nil)
      delivery = build(:portail_delivery, events: [dated, undated])

      groups = helper.delivery_events_by_month(delivery)

      expect(groups[nil].map(&:id)).to eq(["undated"])
      expect(groups.keys.last).to be_nil
    end

    # C'est le mois qui groupe, pas une fenêtre glissante autour de chaque event.
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
    # Un mois accentué : la capitale doit tenir sur une initiale non ASCII.
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

    # La gem omet une extrémité quand le statut V1 est nul ou inconnu.
    it "falls back to a dash for the missing end of a transition" do
      event = build(:portail_event, event_type: "delivery.state_changed", author: "George DUBOIS",
        metadata: {to_state: "done"})

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to eq("George DUBOIS a modifié le statut : — → Traitée")
    end

    # L'auteur vient de l'amont et est interpolé dans une clé `_html`.
    it "escapes the author rather than trusting the upstream" do
      event = build(:portail_event, author: "<script>alert(1)</script>")

      expect(helper.delivery_event_sentence(event)).not_to include("<script>")
    end

    it "falls back to an impersonal actor when the upstream names none" do
      event = build(:portail_event, author: nil)

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to start_with("Un auteur inconnu")
    end

    # Seule la metadata distingue un téléchargement unitaire d'un téléchargement en masse.
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

    # L'amont sert déjà `unknown` quand il ne sait pas qualifier une ligne.
    it "keeps an event the upstream could not qualify" do
      event = build(:portail_event, event_type: "unknown", metadata: {})

      expect(Capybara.string(helper.delivery_event_sentence(event)).text)
        .to end_with("est intervenu sur la démarche")
    end
  end

  describe "#delivery_event_broadcast?" do
    # Une clé absente ne veut pas dire « diffusé ».
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
    # Deux jours distincts : la capitale et le jour doivent venir de la date.
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
