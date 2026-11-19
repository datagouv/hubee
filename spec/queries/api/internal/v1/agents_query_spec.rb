# frozen_string_literal: true

require "rails_helper"

RSpec.describe API::Internal::V1::AgentsQuery do
  def agent(email:, first_name:, last_name:) = create(:agent, email:, first_name:, last_name:)

  def attach(agent, siret: "21750056000016", insee_code: "75056", role: "member")
    link = OrganizationLink.find_or_create_by!(siret:, insee_code:)
    create(:membership, agent:, organization_link: link, role:)
  end

  def search(text) = described_class.new.call(search: text).map(&:email)

  describe "#call with search" do
    let!(:alice) { agent(email: "alice.martin@ville.fr", first_name: "Alice", last_name: "Martin") }
    let!(:jean_pierre) { agent(email: "jp.dlf@ville.fr", first_name: "Jean-Pierre", last_name: "De La Fontaine") }
    let!(:marie_claire) { agent(email: "mc.dupont@ville.fr", first_name: "Marie-Claire", last_name: "Dupont") }

    {
      "alice mar" => "alice.martin@ville.fr",
      "martin al" => "alice.martin@ville.fr",
      "de la fontaine" => "jp.dlf@ville.fr",
      "marie claire" => "mc.dupont@ville.fr",
      "jean pierre de" => "jp.dlf@ville.fr",
      "JP.DLF" => "jp.dlf@ville.fr",
      "mc.dup" => "mc.dupont@ville.fr",
      "Marie-Claire" => "mc.dupont@ville.fr",
      "dupont marie-c" => "mc.dupont@ville.fr"
    }.each do |text, email|
      it "finds #{email} for #{text.inspect}" do
        expect(search(text)).to eq([email])
      end
    end

    it "matches the beginning of a field, not the middle" do
      expect(search("martin")).to eq(["alice.martin@ville.fr"])
      expect(search("tin")).to eq([])
    end

    it "distinguishes accents" do
      agent(email: "helene@ville.fr", first_name: "Hélène", last_name: "Roux")

      expect(search("helene r")).to eq([])
      expect(search("hélène r")).to eq(["helene@ville.fr"])
    end

    # `lower()` de PostgreSQL replie aussi les capitales accentuées, selon la locale de la base.
    it "folds the case of accented capitals" do
      agent(email: "elodie@ville.fr", first_name: "Élodie", last_name: "Roux")

      expect(search("élodie")).to eq(["elodie@ville.fr"])
      expect(search("ÉLODIE r")).to eq(["elodie@ville.fr"])
    end

    it "takes % and _ literally" do
      expect(search("%")).to eq([])
      expect(search("_")).to eq([])
      expect(search("alice_mar")).to eq([])
    end
  end

  describe "#call with an organization" do
    let!(:alice) { agent(email: "alice@ville.fr", first_name: "Alice", last_name: "Martin") }
    let!(:bob) { agent(email: "bob@ville.fr", first_name: "Bob", last_name: "Durand") }

    it "finds the agents attached to a siret" do
      attach(alice)
      attach(bob, siret: "13002526500013", insee_code: "13055")

      expect(described_class.new.call(siret: "21750056000016")).to eq([alice])
    end

    it "restricts to the link of the siret and the insee code" do
      attach(alice, insee_code: "75056")
      attach(bob, insee_code: "75057")

      expect(described_class.new.call(siret: "21750056000016", insee_code: "75057")).to eq([bob])
    end

    it "asks the same membership for the siret and the role" do
      attach(alice, role: "member")
      attach(alice, siret: "13002526500013", insee_code: "13055", role: "local_administrator")
      attach(bob, role: "local_administrator")

      expect(described_class.new.call(siret: "21750056000016", role: "local_administrator")).to eq([bob])
    end

    it "finds an agent by role alone" do
      attach(alice, role: "member")
      attach(bob, role: "local_administrator")

      expect(described_class.new.call(role: "local_administrator")).to eq([bob])
    end

    it "combines the siret with the search" do
      attach(alice)
      attach(bob)

      expect(described_class.new.call(siret: "21750056000016", search: "bob")).to eq([bob])
    end
  end

  describe "#call" do
    it "returns every agent, ordered by email, without criteria" do
      zoe = agent(email: "zoe@ville.fr", first_name: "Zoé", last_name: "Leroy")
      alice = agent(email: "alice@ville.fr", first_name: "Alice", last_name: "Martin")

      expect(described_class.new.call).to eq([alice, zoe])
    end

    it "returns a relation with the memberships, links and accesses preloaded" do
      attach(create(:agent))

      relation = described_class.new.call
      membership = relation.load.sole.memberships.sole

      expect(relation).to be_a(ActiveRecord::Relation)
      expect(membership.association(:organization_link)).to be_loaded
      expect(membership.association(:data_stream_accesses)).to be_loaded
    end

    it "starts from the injected relation" do
      alice = agent(email: "alice@ville.fr", first_name: "Alice", last_name: "Martin")
      agent(email: "bob@ville.fr", first_name: "Bob", last_name: "Durand")

      expect(described_class.new(Agent.where(id: alice.id)).call).to eq([alice])
    end
  end
end
