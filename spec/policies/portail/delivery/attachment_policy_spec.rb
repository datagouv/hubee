# frozen_string_literal: true

require "rails_helper"

RSpec.describe Portail::Delivery::AttachmentPolicy do
  def membership_with(role: "member", process_codes: ["CERTDC"])
    membership = create(:membership, role: role,
      organization_link: create(:organization_link, siret: "22770001000019", insee_code: "77372"))
    process_codes.each { |code| create(:process_access, membership: membership, process_code: code) }
    membership
  end

  def attachment_on(code, **overrides)
    build(:portail_attachment,
      delivery: build(:portail_delivery_summary, data_stream_code: code, **overrides))
  end

  describe "#show?" do
    # La matrice rôle × habilitation, jugée sur la pièce à travers le résumé de sa démarche.
    it "allows a member on a piece of a delivery inside their habilitations" do
      membership = membership_with(process_codes: ["CERTDC"])
      attachment = attachment_on("CERTDC", membership: membership)

      expect(described_class.new(membership, attachment).show?).to be(true)
    end

    it "refuses a member on a piece of a delivery outside their habilitations" do
      membership = membership_with(process_codes: ["AEC"])
      attachment = attachment_on("CERTDC", membership: membership)

      expect(described_class.new(membership, attachment).show?).to be(false)
    end

    it "refuses a member without any habilitation" do
      membership = membership_with(process_codes: [])
      attachment = attachment_on("CERTDC", membership: membership)

      expect(described_class.new(membership, attachment).show?).to be(false)
    end

    it "refuses a piece of a delivery of another organisation" do
      membership = membership_with(process_codes: ["CERTDC"])
      attachment = build(:portail_attachment,
        delivery: build(:portail_delivery_summary, :of_another_organisation, data_stream_code: "CERTDC"))

      expect(described_class.new(membership, attachment).show?).to be(false)
    end

    it "allows a local administrator without habilitation on any piece of their organisation" do
      membership = membership_with(role: "local_administrator", process_codes: [])
      attachment = attachment_on("CERTDC", membership: membership)

      expect(described_class.new(membership, attachment).show?).to be(true)
    end

    it "allows a local administrator on a piece inside their habilitations" do
      membership = membership_with(role: "local_administrator", process_codes: ["CERTDC"])
      attachment = attachment_on("CERTDC", membership: membership)

      expect(described_class.new(membership, attachment).show?).to be(true)
    end

    it "refuses a local administrator on a piece outside their habilitations" do
      membership = membership_with(role: "local_administrator", process_codes: ["AEC"])
      attachment = attachment_on("CERTDC", membership: membership)

      expect(described_class.new(membership, attachment).show?).to be(false)
    end

    # L'état n'entre pas dans l'accès : une pièce en attente d'une démarche lisible se lit, elle
    # ne se livre pas, et c'est la pièce qui le dit.
    it "does not judge the state of the piece" do
      membership = membership_with(process_codes: ["CERTDC"])
      attachment = attachment_on("CERTDC", membership: membership).with(state: "pending")

      expect(described_class.new(membership, attachment).show?).to be(true)
    end
  end
end
