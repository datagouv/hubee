# frozen_string_literal: true

require "rails_helper"
# Le catalogue vit sous db/ : ni autoloadé ni eager-loadé, la spec le charge elle-même.
require Rails.root.join("db/seeds/test_accounts")

RSpec.describe Seeds::TestAccounts do
  describe ".apply!" do
    it "enrols every catalogued account on its organization, with its role" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply! }

      enrolments = Membership.includes(:agent, :organization_link).map do |membership|
        [membership.agent.email, membership.role, membership.organization_link.siret]
      end
      expect(enrolments).to match_array(described_class::ACCOUNTS.map { |account|
        [account.email, account.role, described_class::ORGANIZATIONS.fetch(account.organization).fetch(:siret)]
      })
    end

    it "reads a sensitive process code from the environment rather than from the catalogue" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply! }

      expect(membership_for("membre-sensible@test.proconnect.gouv.fr").process_codes).to eq(["PREMIER"])
      expect(membership_for("jean.dupont@basrec.hubee.numerique.gouv.fr").process_codes).to eq(["SECOND"])
    end

    it "leaves the sensitive accounts unenrolled when the environment declares no code for them" do
      with_sensitive_codes(nil, nil) { described_class.apply! }

      expect(Agent.pluck(:email)).to match_array(
        described_class::ACCOUNTS.reject { |account| account.process_codes.any?(Symbol) }.map(&:email)
      )
    end

    it "replays without duplicating anything, preserving an identity sealed since the first run" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply! }
      agent = Agent.find_by!(email: "membre-etatcivil@test.proconnect.gouv.fr")
      agent.update!(provider_sub: "proconnect-sub-scelle")

      expect { with_sensitive_codes("PREMIER", "SECOND") { described_class.apply! } }.not_to change(Membership, :count)
      expect(Agent.count).to eq(described_class::ACCOUNTS.size)
      expect(agent.reload.provider_sub).to eq("proconnect-sub-scelle")
    end

    it "realigns a role that has drifted from the catalogue" do
      described_class.apply!
      membership = membership_for("membre-etatcivil@test.proconnect.gouv.fr")
      membership.update!(role: "local_administrator")

      described_class.apply!

      expect(membership.reload.role).to eq("member")
    end

    it "revokes a process access that the catalogue no longer declares" do
      described_class.apply!
      membership = membership_for("membre-etatcivil@test.proconnect.gouv.fr")
      ProcessAccess.create!(membership:, process_code: "OBSOLETE")

      described_class.apply!

      expect(membership.reload.process_codes).to eq(["EtatCivil"])
    end

    it "revokes every process access of an account declared without any, restoring its full perimeter" do
      described_class.apply!
      membership = membership_for("admin-total@test.proconnect.gouv.fr")
      ProcessAccess.create!(membership:, process_code: "OBSOLETE")

      described_class.apply!

      expect(membership.reload.process_codes).to be_empty
      expect(Portail::Access::ProcessPerimeter).to be_unrestricted(membership)
    end
  end

  describe ".missing_variables" do
    it "names the sensitive code variables the environment does not declare" do
      with_sensitive_codes("PREMIER", nil) do
        expect(described_class.missing_variables).to eq(["SEED_SENSITIVE_PROCESS_CODE_2"])
      end
    end
  end

  describe ".report" do
    it "states the effective perimeter and the expected second factor of each membership" do
      memberships = with_sensitive_codes("PREMIER", "SECOND") { described_class.apply! }

      expect(described_class.report(memberships)).to include(
        a_string_matching(/admin-total@test\.proconnect\.gouv\.fr\s+local_administrator\s+MFA requise\s+voit tout/),
        a_string_matching(/membre-etatcivil@test\.proconnect\.gouv\.fr\s+member\s+sans MFA\s+limité à EtatCivil/)
      )
    end
  end

  describe ".requested?" do
    it "is requested by an environment that opts in" do
      with_seed_opt_in("true") { expect(described_class.requested?).to be(true) }
    end

    # Le semis local ne pose pas ces comptes : ils visent des organisations que le socle de
    # développement ne connaît pas.
    it "is not requested by an environment that says nothing" do
      with_seed_opt_in(nil) { expect(described_class.requested?).to be(false) }
    end
  end

  def membership_for(email) = Membership.joins(:agent).find_by!(agents: {email:})

  def with_sensitive_codes(*values)
    variables = described_class::SENSITIVE_CODE_VARIABLES.values
    originals = variables.to_h { |name| [name, ENV[name]] }
    variables.zip(values) { |name, value| ENV[name] = value }
    yield
  ensure
    originals.each { |name, value| ENV[name] = value }
  end

  def with_seed_opt_in(value)
    original = ENV["SEED_TEST_ACCOUNTS"]
    ENV["SEED_TEST_ACCOUNTS"] = value
    yield
  ensure
    ENV["SEED_TEST_ACCOUNTS"] = original
  end
end
