# frozen_string_literal: true

require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "associations" do
    subject { build(:membership) }

    it { is_expected.to belong_to(:agent) }
    it { is_expected.to belong_to(:organization_link) }
    it { is_expected.to have_many(:process_accesses) }
  end

  describe "validations" do
    subject { build(:membership) }

    # ignoring_case_sensitivity : le matcher fabrique « une autre valeur » en permutant la
    # casse de l'UUID, que PostgreSQL renormalise — il conclurait à tort que la validation
    # est trop stricte.
    it {
      is_expected.to validate_uniqueness_of(:agent_id)
        .scoped_to(:organization_link_id)
        .ignoring_case_sensitivity
    }
  end

  describe "one membership per SIRET" do
    let(:agent) { create(:agent) }
    let(:link) { create(:organization_link, siret: "99999999900001", insee_code: "001") }

    # ProConnect n'atteste que le SIRET : deux rattachements le partageant seraient
    # indépartageables à la connexion.
    it "refuses a second membership whose link shares the SIRET of an existing one" do
      create(:membership, agent: agent, organization_link: link)

      twin_link = create(:organization_link, siret: "99999999900001", insee_code: "002")
      second = build(:membership, agent: agent, organization_link: twin_link)

      expect(second).not_to be_valid
      expect(second.errors[:organization_link])
        .to eq(["désigne un SIRET auquel l'agent est déjà rattaché"])
    end

    it "refuses moving a membership onto the SIRET of another one" do
      create(:membership, agent: agent, organization_link: link)
      twin_link = create(:organization_link, siret: "99999999900001", insee_code: "002")
      other = create(:membership, agent: agent)

      other.organization_link = twin_link

      expect(other).not_to be_valid
      expect(other.errors[:organization_link])
        .to eq(["désigne un SIRET auquel l'agent est déjà rattaché"])
    end

    it "does not count a membership against itself" do
      membership = create(:membership, agent: agent, organization_link: link)

      membership.job_title = "Cheffe de bureau"

      expect(membership).to be_valid
    end

    it "accepts two agents attached to the two organizations of a shared SIRET" do
      create(:membership, agent: agent, organization_link: link)

      twin_link = create(:organization_link, siret: "99999999900001", insee_code: "002")
      neighbour = build(:membership, agent: create(:agent), organization_link: twin_link)

      expect(neighbour).to be_valid
    end

    it "accepts one agent attached to two distinct SIRET" do
      create(:membership, agent: agent, organization_link: link)

      elsewhere = build(:membership, agent: agent,
        organization_link: create(:organization_link, siret: "99999999900002"))

      expect(elsewhere).to be_valid
    end
  end

  describe "role" do
    # Le moindre privilège est le défaut : un rôle non accordé n'est pas administrateur.
    it "makes a membership a plain member until told otherwise" do
      expect(create(:membership)).to be_member
      expect(create(:membership, :local_administrator)).to be_local_administrator
    end

    it "refuses a role outside the closed list" do
      expect(build(:membership, role: "national_administrator")).not_to be_valid
    end
  end

  describe "phone_number" do
    it "stores what an agent types in its international form" do
      expect(create(:membership, phone_number: "01 42 76 20 00").phone_number)
        .to eq("+33142762000")
      expect(create(:membership, phone_number: "0692 12 34 56").phone_number)
        .to eq("+262692123456")
    end

    # Rejeter plutôt qu'effacer : un numéro perdu en silence ne serait signalé à personne.
    it "rejects a number it could not bring to international form" do
      membership = build(:membership, phone_number: "12345")

      expect(membership).not_to be_valid
      expect(membership.errors[:phone_number]).to be_present
    end

    it "accepts having no phone number at all" do
      expect(build(:membership, phone_number: nil)).to be_valid
      expect(build(:membership, phone_number: "")).to be_valid
    end
  end

  describe "job_title" do
    it "bounds the job title" do
      expect(build(:membership, job_title: "a" * 255)).to be_valid
      expect(build(:membership, job_title: "a" * 256)).not_to be_valid
    end
  end

  describe "labels" do
    it "names the attributes and each role in French" do
      expect(described_class.human_attribute_name(:role)).to eq("Rôle")
      expect(described_class.human_attribute_name(:job_title)).to eq("Fonction")
      expect(described_class.human_attribute_name(:phone_number)).to eq("Téléphone")
      expect(described_class.human_attribute_name("roles.member")).to eq("Agent")
      expect(described_class.human_attribute_name("roles.local_administrator"))
        .to eq("Administrateur local")
    end
  end

  describe "#process_codes" do
    it "lists the codes of the habilitated data streams" do
      membership = create(:membership)
      create(:process_access, membership: membership, process_code: "CERTDC")
      create(:process_access, membership: membership, process_code: "AEC")

      expect(membership.process_codes).to contain_exactly("CERTDC", "AEC")
    end

    it "is empty without habilitation" do
      expect(create(:membership).process_codes).to eq([])
    end
  end
end
