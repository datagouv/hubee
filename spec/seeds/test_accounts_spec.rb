# frozen_string_literal: true

require "rails_helper"
# Le catalogue vit sous db/ : ni autoloadé ni eager-loadé, la spec le charge elle-même.
require Rails.root.join("db/seeds/test_accounts")

RSpec.describe Seeds::TestAccounts do
  describe ".apply!" do
    it "enrols every catalogued account on its organization, with its role" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[local deployed]) }

      enrolments = Membership.includes(:agent, :organization_link).map do |membership|
        [membership.agent.email, membership.role, membership.organization_link.siret]
      end
      expect(enrolments).to match_array(described_class::ACCOUNTS.map { |account|
        [account.email, account.role, described_class::ORGANIZATIONS.fetch(account.organization).fetch(:siret)]
      })
    end

    it "enrols only the accounts of the requested scopes, and only their organizations" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }

      deployed = described_class::ACCOUNTS.select { |account| account.scope == :deployed }
      expect(Agent.pluck(:email)).to match_array(deployed.map(&:email))
      expect(OrganizationLink.pluck(:siret)).to contain_exactly("21260274200018", "22010001000010")
    end

    it "reads a sensitive process code from the environment rather than from the catalogue" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }

      expect(membership_for("membre-sensible@test.proconnect.gouv.fr").process_codes).to eq(["PREMIER"])
      expect(membership_for("jean.dupont@basrec.hubee.numerique.gouv.fr").process_codes).to eq(["SECOND"])
    end

    it "leaves the sensitive accounts unenrolled when the environment declares no code for them" do
      with_sensitive_codes(nil, nil) { described_class.apply!(%i[deployed]) }

      expect(Agent.pluck(:email)).to match_array(
        described_class.accounts(%i[deployed]).reject { |account| account.process_codes.any?(Symbol) }.map(&:email)
      )
    end

    it "replays without duplicating anything, preserving an identity sealed since the first run" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }
      agent = Agent.find_by!(email: "membre-etatcivil@test.proconnect.gouv.fr")
      agent.update!(provider_sub: "proconnect-sub-scelle")

      expect {
        with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }
      }.not_to change(Membership, :count)
      expect(Agent.count).to eq(described_class.accounts(%i[deployed]).size)
      expect(agent.reload.provider_sub).to eq("proconnect-sub-scelle")
    end

    it "realigns a role that has drifted from the catalogue" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }
      membership = membership_for("membre-etatcivil@test.proconnect.gouv.fr")
      membership.update!(role: "local_administrator")

      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }

      expect(membership.reload.role).to eq("member")
    end

    it "revokes a process access that the catalogue no longer declares" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }
      membership = membership_for("membre-etatcivil@test.proconnect.gouv.fr")
      ProcessAccess.create!(membership:, process_code: "OBSOLETE")

      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }

      expect(membership.reload.process_codes).to eq(["EtatCivil"])
    end

    it "revokes every process access of an account declared without any, restoring its full perimeter" do
      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }
      membership = membership_for("admin-total@test.proconnect.gouv.fr")
      ProcessAccess.create!(membership:, process_code: "OBSOLETE")

      with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }

      expect(membership.reload.process_codes).to be_empty
      expect(Portail::Access::ProcessPerimeter).to be_unrestricted(membership)
    end
  end

  describe ".missing_variables" do
    it "names the sensitive code variables the selected accounts need and the environment does not declare" do
      with_sensitive_codes("PREMIER", nil) do
        expect(described_class.missing_variables(%i[deployed])).to eq(["SEED_SENSITIVE_PROCESS_CODE_2"])
        # Aucun compte local ne désigne le second code : son absence ne prive personne.
        expect(described_class.missing_variables(%i[local])).to be_empty
      end
    end
  end

  describe ".report" do
    it "states the effective perimeter and the expected second factor of each membership" do
      memberships = with_sensitive_codes("PREMIER", "SECOND") { described_class.apply!(%i[deployed]) }

      expect(described_class.report(memberships)).to include(
        a_string_matching(/admin-total@test\.proconnect\.gouv\.fr\s+local_administrator\s+MFA requise\s+voit tout/),
        a_string_matching(/membre-etatcivil@test\.proconnect\.gouv\.fr\s+member\s+sans MFA\s+limité à EtatCivil/)
      )
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
end
