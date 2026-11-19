# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::AgentUpdateForm do
  let(:agent) { create(:agent, email: "alice.martin@ville.fr", civility: "ms") }

  def errors_of(form)
    form.validate
    form.errors.details
  end

  describe "#changes" do
    it "is empty when no key is received" do
      form = described_class.new(agent:)

      expect(form.changes).to eq({})
      expect(form.email_changed?).to be(false)
    end

    it "gives the before and after of each received field" do
      form = described_class.new(agent:, email: "alice.dupont@ville.fr", civility: "mr")

      expect(form.changes).to eq(email: ["alice.martin@ville.fr", "alice.dupont@ville.fr"], civility: ["ms", "mr"])
      expect(form.email_changed?).to be(true)
    end

    it "leaves out a field that was not received" do
      form = described_class.new(agent:, civility: "mr")

      expect(form.changes).to eq(civility: ["ms", "mr"])
      expect(form.email_changed?).to be(false)
    end

    it "sees no change for the same address in another case" do
      form = described_class.new(agent:, email: " Alice.Martin@Ville.fr ")

      expect(form.changes).to eq({})
      expect(form.email_changed?).to be(false)
    end

    it "sees no change for the same civility" do
      expect(described_class.new(agent:, civility: "ms").changes).to eq({})
    end

    it "reads a blank civility as an erasure" do
      expect(described_class.new(agent:, civility: "").changes).to eq(civility: ["ms", nil])
    end

    it "reads a null civility as an erasure" do
      expect(described_class.new(agent:, civility: nil).changes).to eq(civility: ["ms", nil])
    end
  end

  describe "#valid?" do
    it "accepts an update without any key" do
      expect(described_class.new(agent:)).to be_valid
    end

    it "accepts a well-formed address and a civility of the closed list" do
      expect(described_class.new(agent:, email: "alice.dupont@ville.fr", civility: "mr")).to be_valid
    end

    it "refuses an address that is blank" do
      expect(errors_of(described_class.new(agent:, email: ""))).to eq(email: [{error: :blank}])
    end

    it "refuses an address that is null" do
      expect(errors_of(described_class.new(agent:, email: nil))).to eq(email: [{error: :blank}])
    end

    it "refuses a malformed address" do
      expect(errors_of(described_class.new(agent:, email: "pas-une-adresse"))).to eq(email: [{error: :invalid, value: "pas-une-adresse"}])
    end

    # La borne d'une adresse électronique (RFC 5321) : au-delà, aucune boîte ne la reçoit.
    it "accepts an address of 254 characters and refuses a longer one" do
      domain = "#{"b" * 63}.#{"c" * 63}.#{"d" * 58}.fr"
      longest = "#{"a" * 64}@#{domain}"

      expect(longest.length).to eq(254)
      expect(described_class.new(agent:, email: longest)).to be_valid
      expect(errors_of(described_class.new(agent:, email: "a#{longest}"))).to eq(email: [{error: :too_long, count: 254}])
    end

    it "refuses a civility outside the closed list" do
      expect(errors_of(described_class.new(agent:, civility: "x"))).to eq(civility: [{error: :inclusion, value: "x"}])
    end
  end

  describe "#valid_on?" do
    it "is true for a field without reason and false for one with" do
      form = described_class.new(agent:, email: "pas-une-adresse")
      form.validate

      expect(form.valid_on?(:civility)).to be(true)
      expect(form.valid_on?(:email)).to be(false)
    end
  end

  describe "#error_details" do
    it "gives the reasons by field" do
      form = described_class.new(agent:, email: "", civility: "x")
      form.validate

      expect(form.error_details).to eq(email: ["doit être rempli(e)"], civility: ["n'est pas inclus(e) dans la liste"])
    end
  end
end
