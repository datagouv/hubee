# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("script/2026-10-beta-v2/importer_agents")
require Rails.root.join("script/2026-10-beta-v2/generer_import")

RSpec.describe Portail::BetaImport::Importer do
  let(:entry) do
    {
      "email" => "camille.martin@exemple.fr", "first_name" => "Camille", "last_name" => "Martin",
      "siret" => "21260274200018", "insee_code" => "26274", "role" => "member",
      "data_stream_codes" => %w[EtatCivil recensementCitoyen]
    }
  end

  describe ".import" do
    it "enrols the agent on the organization with the role and processes of the entry" do
      result = described_class.import(entry)

      membership = Agent.find_by!(email: "camille.martin@exemple.fr").memberships.sole
      expect(result.error).to be_nil
      expect(result.changes).to eq(["agent créé", "rattachement créé", "+ EtatCivil", "+ recensementCitoyen"])
      expect(membership.organization_link).to have_attributes(siret: "21260274200018", insee_code: "26274")
      expect(membership.role).to eq("member")
      expect(membership.data_stream_codes).to match_array(%w[EtatCivil recensementCitoyen])
    end

    it "replays an entry without changing anything" do
      described_class.import(entry)

      expect { expect(described_class.import(entry).changes).to eq([]) }
        .not_to change { [Agent.count, OrganizationLink.count, Membership.count, DataStreamAccess.count] }
    end

    it "realigns the role and the processes on the entry, reporting each change" do
      described_class.import(entry)

      result = described_class.import(entry.merge("role" => "local_administrator", "data_stream_codes" => %w[EtatCivil CERTDC]))

      expect(result.changes).to eq(["rôle member → local_administrator", "− recensementCitoyen", "+ CERTDC"])
      expect(result.membership.reload.data_stream_codes).to match_array(%w[EtatCivil CERTDC])
    end

    it "leaves the identity of an existing agent untouched" do
      agent = create(:agent, email: "camille.martin@exemple.fr", first_name: "Cam", last_name: "M.", provider_sub: "sub-scelle")

      described_class.import(entry)

      expect(agent.reload).to have_attributes(first_name: "Cam", last_name: "M.", provider_sub: "sub-scelle")
    end

    it "reports an agent already attached to another organization of the same SIRET, and writes nothing" do
      agent = create(:agent, email: "camille.martin@exemple.fr")
      create(:membership, agent:, organization_link: create(:organization_link, siret: "21260274200018", insee_code: "26999"))

      result = described_class.import(entry)

      expect(result.error).to include("SIRET auquel l'agent est déjà rattaché")
      expect(OrganizationLink.where(insee_code: "26274")).to be_empty
      expect(agent.memberships.count).to eq(1)
    end

    it "leaves nothing behind for a failed entry, even inside an enclosing transaction like the sandbox console" do
      ApplicationRecord.transaction do
        result = described_class.import(entry.merge("role" => "superadmin"))

        expect(result.error).to be_present
        expect(Agent.where(email: "camille.martin@exemple.fr")).to be_empty
      end
    end
  end

  describe ".call" do
    it "prints the fingerprint of the loaded file, then the role, second factor, perimeter and changes of each entry" do
      stub_const("Portail::Access::SensitiveDataStreams::CODES", %w[DEMO_SENSIBLE])
      io = StringIO.new
      json = [
        entry,
        entry.merge("email" => "admin@exemple.fr", "role" => "local_administrator", "data_stream_codes" => []),
        entry.merge("email" => "rien@exemple.fr", "siret" => "13002526500013", "data_stream_codes" => [])
      ].to_json

      described_class.call(json, io:)

      fingerprint = Digest::SHA256.file(Rails.root.join("script/2026-10-beta-v2/importer_agents.rb")).hexdigest
      expect(io.string.lines(chomp: true)).to eq([
        "importer_agents.rb sha256 #{fingerprint}",
        "camille.martin@exemple.fr | member | sans MFA | limité à EtatCivil, recensementCitoyen | " \
          "agent créé, rattachement créé, + EtatCivil, + recensementCitoyen",
        "admin@exemple.fr | local_administrator | MFA requise | voit tout | agent créé, rattachement créé",
        "rien@exemple.fr | member | sans MFA | voit rien | agent créé, rattachement créé"
      ])
    end

    it "prints a failed entry and carries on with the next ones" do
      io = StringIO.new

      described_class.call([entry.merge("role" => "superadmin"), entry.merge("email" => "suivant@exemple.fr")].to_json, io:)

      expect(io.string.lines(chomp: true).drop(1)).to match([
        start_with("camille.martin@exemple.fr | ERREUR | "),
        end_with("| agent créé, rattachement créé, + EtatCivil, + recensementCitoyen")
      ])
    end
  end

  describe "a batch from the generator, pasted in the console" do
    it "enrols its entries, with a name holding quotes and interpolation verbatim" do
      row = Portail::BetaImport::Consolidation::Row.new(
        email: entry["email"], status: "injecté", reason: "",
        entry: entry.merge("last_name" => %q(D'Exemple #{raise "interpolé"})).transform_keys(&:to_sym)
      )
      batch = Portail::BetaImport::Output.batches([row]).sole

      expect { eval(batch, TOPLEVEL_BINDING) }.to output(/camille\.martin@exemple\.fr \| member/).to_stdout # rubocop:disable Security/Eval

      expect(Agent.find_by!(email: "camille.martin@exemple.fr").last_name).to eq(%q(D'Exemple #{raise "interpolé"}))
    end
  end
end
