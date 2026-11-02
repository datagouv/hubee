# frozen_string_literal: true

require "rails_helper"

# Les champs d'un rattachement dans la liste des agents, chacun avec son repli.
RSpec.describe Portail::MembershipsHelper, type: :helper do
  describe "#membership_agent_name" do
    it "joins the first and last names, keeps the one present, falls back to a dash" do
      expect(helper.membership_agent_name(build(:membership, agent: build(:agent, first_name: "Camille", last_name: "Martin"))))
        .to eq("Camille Martin")
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

    def items(cell) = cell.all("li").map { |item| item.text.strip }

    it "names each subscribed data stream, in name order, without a badge" do
      rendered = cell(membership_with("CERTDC", "AEC"),
        names: {"CERTDC" => "Certificat de décès électronique", "AEC" => "Actes d'état civil"},
        subscribed_codes: ["CERTDC", "AEC"])

      expect(items(rendered)).to eq(["Actes d'état civil – AEC", "Certificat de décès électronique – CERTDC"])
      expect(rendered).not_to have_css(".fr-badge")
    end

    it "flags a data stream the organisation does not subscribe to" do
      rendered = cell(membership_with("CERTDC", "HORS"),
        names: {"CERTDC" => "Certificat de décès électronique"}, subscribed_codes: ["CERTDC"])

      expect(rendered).to have_css("li", text: "HORS") { |item| item.has_css?("p.fr-badge.fr-badge--warning", text: "Non abonné") }
      expect(rendered).to have_css("li", text: "Certificat de décès électronique – CERTDC") { |item| item.has_no_css?(".fr-badge") }
    end

    # Des codes renseignés bornent l'administrateur comme un membre : non abonnés, ils ne lui
    # ouvrent rien, et il ne doit pas passer pour habilité sur tout.
    it "flags an administrator's unsubscribed data streams instead of granting every one" do
      rendered = cell(membership_with("HORS", role: "local_administrator"), names: {}, subscribed_codes: [])

      expect(rendered).to have_css("li", text: "HORS") { |item| item.has_css?("p.fr-badge--warning", text: "Non abonné") }
      expect(rendered).not_to have_text("Tous les flux")
    end

    # Seul le nom manque : l'abonnement existe, rien à signaler.
    it "shows the bare code of a subscribed data stream without a name" do
      rendered = cell(membership_with("SANS_NOM"), names: {}, subscribed_codes: ["SANS_NOM"])

      expect(items(rendered)).to eq(["SANS_NOM"])
      expect(rendered).not_to have_css(".fr-badge")
    end

    # Rien de vérifié, rien d'accusé.
    it "shows bare codes without a badge when the subscriptions could not be read" do
      rendered = cell(membership_with("CERTDC"), names: {}, subscribed_codes: nil)

      expect(items(rendered)).to eq(["CERTDC"])
      expect(rendered).not_to have_css(".fr-badge")
    end

    it "says an administrator without habilitation reaches every data stream" do
      rendered = cell(membership_with(role: "local_administrator"), names: {}, subscribed_codes: [])

      expect(rendered).to have_text("Tous les flux")
      expect(rendered).not_to have_css("li")
    end

    it "says a member without habilitation reaches none" do
      rendered = cell(membership_with, names: {}, subscribed_codes: [])

      expect(rendered).to have_text("Aucun flux")
      expect(rendered).not_to have_css("li")
    end
  end
end
