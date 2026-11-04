# frozen_string_literal: true

require "rails_helper"

# Les champs d'un rattachement dans la liste des agents, chacun avec son repli.
RSpec.describe Portail::MembershipsHelper, type: :helper do
  describe "#membership_agent_name" do
    # Le nom de famille d'abord, en capitales comme dans une liste administrative : la liste est
    # triée sur lui, et « Martin Thomas » ne dirait pas lequel est le prénom.
    it "puts the last name first, in capitals, keeps the one present, falls back to a dash" do
      expect(helper.membership_agent_name(build(:membership, agent: build(:agent, first_name: "Camille", last_name: "Martin"))))
        .to eq("MARTIN Camille")
      expect(helper.membership_agent_name(build(:membership, agent: build(:agent, first_name: "Élise", last_name: "de La Fontaine"))))
        .to eq("DE LA FONTAINE Élise")
      expect(helper.membership_agent_name(build(:membership, agent: build(:agent, first_name: nil, last_name: "Martin"))))
        .to eq("MARTIN")
      expect(helper.membership_agent_name(build(:membership, agent: build(:agent, first_name: "Camille", last_name: nil))))
        .to eq("Camille")
      expect(helper.membership_agent_name(build(:membership, agent: build(:agent, first_name: nil, last_name: ""))))
        .to eq("—")
    end
  end

  describe "#membership_email" do
    it "shows the agent's email address" do
      expect(helper.membership_email(build(:membership, agent: build(:agent, email: "camille.martin@example.gouv.fr"))))
        .to eq("camille.martin@example.gouv.fr")
    end
  end

  describe "#membership_job_title" do
    it "shows the job title, or a dash" do
      expect(helper.membership_job_title(build(:membership, job_title: "Juriste"))).to eq("Juriste")
      expect(helper.membership_job_title(build(:membership, job_title: nil))).to eq("—")
    end
  end

  describe "#membership_phone_number" do
    it "shows the phone number, or a dash" do
      expect(helper.membership_phone_number(build(:membership, phone_number: "+33123456789"))).to eq("+33123456789")
      expect(helper.membership_phone_number(build(:membership, phone_number: nil))).to eq("—")
    end
  end

  describe "#membership_role" do
    it "names each role in a badge" do
      expect(Capybara.string(helper.membership_role(build(:membership, :local_administrator))))
        .to have_css("p.fr-badge", text: "Administrateur local")
      expect(Capybara.string(helper.membership_role(build(:membership))))
        .to have_css("p.fr-badge", text: "Membre")
    end
  end

  describe "#membership_last_signed_in_at" do
    it "writes the date in full, or says the agent never signed in" do
      signed_in_at = Time.zone.local(2026, 10, 20, 14, 30)

      expect(helper.membership_last_signed_in_at(build(:membership, last_signed_in_at: signed_in_at)))
        .to eq(I18n.l(signed_in_at, format: :long))
      expect(helper.membership_last_signed_in_at(build(:membership, last_signed_in_at: nil))).to eq("Jamais")
    end
  end

  describe "#membership_data_streams" do
    def membership_with(*codes, role: "member")
      create(:membership, role:).tap do |membership|
        codes.each { |code| create(:data_stream_access, membership:, data_stream_code: code) }
      end
    end

    def cell(membership, names:, subscribed_codes:)
      Capybara.string(helper.membership_data_streams(membership, names:, subscribed_codes:))
    end

    def tags(cell) = cell.all("ul.fr-tags-group li p.fr-tag").map { |tag| tag.text.strip }

    # Des tags et non une liste : douze noms passent à la ligne dans la cellule au lieu d'étirer
    # la ligne de l'agent d'autant.
    it "names each subscribed data stream in a tag, in name order, without a badge" do
      rendered = cell(membership_with("CERTDC", "AEC"),
        names: {"CERTDC" => "Certificat de décès électronique", "AEC" => "Actes d'état civil"},
        subscribed_codes: ["CERTDC", "AEC"])

      expect(tags(rendered)).to eq(["Actes d'état civil", "Certificat de décès électronique"])
      expect(rendered).not_to have_css(".membership-data-streams__unsubscribed")
    end

    # Le tag lui-même change d'allure : un badge à côté se perdait parmi douze tags. Le texte le
    # dit aussi, la couleur seule ne suffit pas.
    it "flags a data stream the organisation does not subscribe to" do
      rendered = cell(membership_with("CERTDC", "HORS"),
        names: {"CERTDC" => "Certificat de décès électronique"}, subscribed_codes: ["CERTDC"])

      expect(rendered).to have_css("p.fr-tag.fr-icon-warning-fill.membership-data-streams__unsubscribed", exact_text: "HORS · non abonné")
      expect(rendered).to have_css("p.fr-tag:not(.membership-data-streams__unsubscribed)", exact_text: "Certificat de décès électronique")
    end

    # Des codes renseignés bornent l'administrateur comme un membre : non abonnés, ils ne lui
    # ouvrent rien, et il ne doit pas passer pour habilité sur tout.
    it "flags an administrator's unsubscribed data streams instead of granting every one" do
      rendered = cell(membership_with("HORS", role: "local_administrator"), names: {}, subscribed_codes: [])

      expect(rendered).to have_css("p.membership-data-streams__unsubscribed", exact_text: "HORS · non abonné")
      expect(rendered).not_to have_text("Tous les flux")
    end

    # Seul le nom manque : l'abonnement existe, rien à signaler.
    it "shows the bare code of a subscribed data stream without a name" do
      rendered = cell(membership_with("SANS_NOM"), names: {}, subscribed_codes: ["SANS_NOM"])

      expect(tags(rendered)).to eq(["SANS_NOM"])
      expect(rendered).not_to have_css(".membership-data-streams__unsubscribed")
    end

    # Rien de vérifié, rien d'accusé.
    it "shows bare codes without a badge when the subscriptions could not be read" do
      rendered = cell(membership_with("CERTDC"), names: {}, subscribed_codes: nil)

      expect(tags(rendered)).to eq(["CERTDC"])
      expect(rendered).not_to have_css(".membership-data-streams__unsubscribed")
    end

    # Une règle et non une liste : elle vaut aussi pour les abonnements à venir. Le lien répond à
    # « lesquels ? », et son nom accessible dit où il mène.
    it "says an administrator without habilitation reaches every data stream, linking to the subscriptions" do
      rendered = cell(membership_with(role: "local_administrator"), names: {}, subscribed_codes: [])

      expect(rendered).to have_link("Tous les flux", href: "/abonnements")
      expect(rendered).to have_css("a[aria-label='Tous les flux, voir les abonnements de la structure']")
      expect(rendered).not_to have_css(".fr-tag")
    end

    it "says a member without habilitation reaches none" do
      rendered = cell(membership_with, names: {}, subscribed_codes: [])

      expect(rendered).to have_text("Aucun flux")
      expect(rendered).not_to have_css(".fr-tag")
    end
  end
end
