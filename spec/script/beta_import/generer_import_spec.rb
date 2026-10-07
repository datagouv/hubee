# frozen_string_literal: true

require "rails_helper"
require "open3"
require Rails.root.join("script/2026-10-beta-v2/generer_import")

RSpec.describe Portail::BetaImport::Output do
  let(:entry) do
    {
      email: "camille.martin@exemple.fr", first_name: "Camille", last_name: %q(D'Exemple #{x}),
      siret: "21260274200018", insee_code: "26274", role: "member", data_stream_codes: ["EtatCivil"]
    }
  end
  let(:rows) do
    [
      Portail::BetaImport::Consolidation::Row.new(email: entry[:email], status: "injecté", reason: "", entry:),
      Portail::BetaImport::Consolidation::Row.new(
        email: "absent@exemple.fr", status: "anomalie", reason: "absent de l'export Keycloak", entry: nil
      )
    ]
  end

  describe ".report" do
    it "lists every row of the spreadsheet with whether it is injected" do
      expect(described_class.report(rows)).to eq(<<~CSV)
        email;injecte;statut;raison
        camille.martin@exemple.fr;oui;injecté;
        absent@exemple.fr;non;anomalie;absent de l'export Keycloak
      CSV
    end
  end

  describe ".batches" do
    it "embeds the injected entries as data the console parses back verbatim, never as Ruby" do
      batch = described_class.batches(rows).sole
      json = batch[/<<~'JSON'\)\n(.*)^JSON$/m, 1]

      expect(batch).to start_with(%(require Rails.root.join("script/2026-10-beta-v2/importer_agents").to_s\n))
      expect(JSON.parse(json)).to eq([entry.transform_keys(&:to_s)])
    end

    it "splits the entries into batches of fifteen" do
      many = Array.new(16) { |index| rows.first.with(entry: entry.merge(email: "agent#{index}@exemple.fr")) }

      expect(described_class.batches(many).map { |batch| batch.scan('"email"').size }).to eq([15, 1])
    end
  end
end

RSpec.describe "generer_import.rb command line" do
  let(:script) { Rails.root.join("script/2026-10-beta-v2/generer_import.rb").to_s }
  let(:sources) do
    Dir.mktmpdir.tap do |dir|
      File.write(File.join(dir, "u.csv"), "\uFEFFNom,Prénom,Adresse e-mail,Organisation,Type Utilisateur HubEE\n" \
        "Martin,Camille,camille.martin@exemple.fr,Commune,AGT\n")
      File.write(File.join(dir, "o.csv"), "Organisation,CompanyRegister,BranchCode\nCommune,21260274200018,26274\n")
      File.write(File.join(dir, "k.csv"), [
        "email;keycloak_id;enabled;required_actions;first_name;last_name;user_type;siret;branch_code;" \
          "organization_name;unrestricted;process_code;process_status;anomalie",
        "camille.martin@exemple.fr;kc-1;true;;Camille;Martin;AGT;21260274200018;26274;COMMUNE;false;EtatCivil;retenu;"
      ].join("\n"))
    end
  end

  def generate(output) = Open3.capture2e("ruby", script, *%w[u.csv o.csv k.csv].map { |name| File.join(sources, name) }, output)

  it "writes the report and the batches outside the repository, without Rails" do
    output = File.join(Dir.mktmpdir, "sortie")
    log, status = generate(output)

    expect(status).to be_success, log
    expect(log).to include("injecté : 1")
    expect(File.read(File.join(output, "rapport.csv"))).to include("camille.martin@exemple.fr;oui;injecté;")
    expect(File.read(File.join(output, "lot-01.txt"))).to include(%("data_stream_codes":["EtatCivil"]))
  end

  it "refuses to write personal data into the repository outside tmp/" do
    log, status = generate(Rails.root.join("script/2026-10-beta-v2/sortie").to_s)

    expect(status).not_to be_success
    expect(log).to include("hors du dépôt, ou sous tmp/")
    expect(Rails.root.join("script/2026-10-beta-v2/sortie")).not_to exist
  end
end
