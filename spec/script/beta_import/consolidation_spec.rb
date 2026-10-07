# frozen_string_literal: true

require "rails_helper"
# Hors autoload, comme db/seeds : la spec charge le fichier elle-même.
require Rails.root.join("script/2026-10-beta-v2/consolidation")

RSpec.describe Portail::BetaImport::Consolidation do
  let(:organizations) do
    <<~CSV
      Organisation,CompanyRegister,BranchCode,E-mails ADM_LOC,Commentaire
      Commune d'Exemple,21260274200018,26274,,
      "Syndicat des eaux, Exemple",21260274200019,26275,,
    CSV
  end

  def users(*rows)
    header = "Nom,Prénom,Adresse e-mail,Organisation,Type Utilisateur HubEE,Compte ProConnect créé,2FA ProConnect configuré,Commentaire\n"
    header + rows.map { |row| user_row(**row) }.join
  end

  def user_row(email: "camille.martin@exemple.fr", account_type: "AGT", organization: "Commune d'Exemple",
    first_name: "Camille", last_name: "Martin")
    CSV.generate_line([last_name, first_name, email, organization, account_type, "oui", "oui", ""])
  end

  def keycloak(*rows)
    header = "email;keycloak_id;enabled;required_actions;first_name;last_name;user_type;siret;branch_code;" \
      "organization_name;unrestricted;process_code;process_status;anomalie"
    [header, *rows.map { |row| keycloak_row(**row) }].join("\n")
  end

  def keycloak_row(**overrides)
    {
      email: "camille.martin@exemple.fr", keycloak_id: "kc-1", enabled: "true", required_actions: "",
      first_name: "Camille", last_name: "Martin", user_type: "AGT", siret: "21260274200018",
      branch_code: "26274", organization_name: "COMMUNE D'EXEMPLE", unrestricted: "false",
      process_code: "EtatCivil", process_status: "retenu", anomalie: ""
    }.merge(overrides).values.join(";")
  end

  def consolidate(users_csv, keycloak_csv)
    described_class.call(users: users_csv, organizations:, keycloak: keycloak_csv)
  end

  it "injects a member with the processes Keycloak retains, under the organization of the spreadsheet" do
    rows = consolidate(
      users({email: "Camille.Martin@Exemple.fr", first_name: "Camille-Anne", last_name: "Martin-Durand"}),
      keycloak({}, {process_code: "recensementCitoyen"})
    )

    expect(rows).to eq([
      described_class::Row.new(
        email: "camille.martin@exemple.fr", status: "injecté", reason: "",
        entry: {
          email: "camille.martin@exemple.fr", first_name: "Camille-Anne", last_name: "Martin-Durand",
          siret: "21260274200018", insee_code: "26274", role: "member",
          data_stream_codes: %w[EtatCivil recensementCitoyen]
        }
      )
    ])
  end

  it "falls back on Keycloak's first and last names when the spreadsheet leaves them blank" do
    rows = consolidate(users({first_name: "", last_name: " "}), keycloak({first_name: "Cam", last_name: "Mart"}))

    expect(rows.first.entry).to include(first_name: "Cam", last_name: "Mart")
  end

  it "injects an unrestricted local administrator with no process" do
    rows = consolidate(
      users({account_type: "ADM_LOC"}),
      keycloak({user_type: "ADM_LOC", unrestricted: "true", process_code: "", process_status: ""})
    )

    expect(rows.first.status).to eq("injecté")
    expect(rows.first.entry).to include(role: "local_administrator", data_stream_codes: [])
  end

  it "accepts the account types written out in full" do
    rows = described_class.call(
      users: users(
        {email: "agent@exemple.fr", account_type: " Agent "},
        {email: "admin@exemple.fr", account_type: "Admin  local"},
        {email: "administrateur@exemple.fr", account_type: "Administrateur local"}
      ),
      organizations:,
      keycloak: keycloak({email: "agent@exemple.fr"}, {email: "admin@exemple.fr"}, {email: "administrateur@exemple.fr"})
    )

    expect(rows.map { |row| row.entry[:role] }).to eq(%w[member local_administrator local_administrator])
  end

  it "injects a local administrator of the spreadsheet bounded to the processes of a Keycloak agent" do
    rows = consolidate(users({account_type: "ADM_LOC"}), keycloak({}))

    expect(rows.first.status).to eq("injecté")
    expect(rows.first.entry).to include(role: "local_administrator", data_stream_codes: ["EtatCivil"])
  end

  it "lists the processes dropped for lack of subscription in the reason of an injected row" do
    rows = consolidate(users({}), keycloak({}, {process_code: "Obsolete", process_status: "hors_abonnement"}))

    expect(rows.first.status).to eq("injecté")
    expect(rows.first.reason).to eq("process hors abonnement retirés : Obsolete")
    expect(rows.first.entry[:data_stream_codes]).to eq(["EtatCivil"])
  end

  it "warns that a member of the spreadsheet, unrestricted local administrator in Keycloak, will see nothing" do
    rows = consolidate(
      users({}),
      keycloak({user_type: "ADM_LOC", unrestricted: "true", process_code: "", process_status: ""})
    )

    expect(rows.first.status).to eq("avertissement")
    expect(rows.first.reason).to eq("ne verra rien : admin local sans process dans Keycloak, agent dans le tableur")
    expect(rows.first.entry).to include(role: "member", data_stream_codes: [])
  end

  it "warns that a member whose processes all lack a subscription will see nothing" do
    rows = consolidate(users({}), keycloak({process_status: "hors_abonnement"}))

    expect(rows.first.status).to eq("avertissement")
    expect(rows.first.reason).to eq("ne verra rien : process tous hors abonnement (EtatCivil)")
  end

  it "warns that a member without any process in Keycloak will see nothing" do
    rows = consolidate(users({}), keycloak({process_code: "", process_status: ""}))

    expect(rows.first.status).to eq("avertissement")
    expect(rows.first.reason).to eq("ne verra rien : aucun process dans Keycloak")
  end

  it "rejects a local administrator whose processes all lack a subscription, who would otherwise see everything" do
    rows = consolidate(users({account_type: "ADM_LOC"}), keycloak({process_status: "hors_abonnement"}))

    expect(rows.first.status).to eq("anomalie")
    expect(rows.first.reason).to eq("admin local dont tous les process sont hors abonnement : il verrait tout")
    expect(rows.first.entry).to be_nil
  end

  it "accepts a branch code the export resolved through hub-api" do
    rows = consolidate(users({}), keycloak({anomalie: "branch_code_resolu"}))

    expect(rows.first.status).to eq("injecté")
  end

  it "rejects an account whose joined export anomalies hold one besides the resolved branch code" do
    rows = consolidate(users({}), keycloak({anomalie: "branch_code_resolu|type_hors_perimetre"}))

    expect(rows.first.status).to eq("anomalie")
    expect(rows.first.reason).to eq("export Keycloak : type_hors_perimetre")
  end

  it "rejects an account whose processes the export could not cross, never retaining them" do
    rows = consolidate(users({}), keycloak({process_status: "", anomalie: "branch_code_ambigu"}))

    expect(rows.first.status).to eq("anomalie")
    expect(rows.first.reason).to eq("export Keycloak : branch_code_ambigu")
  end

  it "reads an export field quoted for holding the separator" do
    rows = consolidate(users({}), keycloak({organization_name: %("COMMUNE; D'EXEMPLE")}))

    expect(rows.first.status).to eq("injecté")
    expect(rows.first.entry).to include(siret: "21260274200018", data_stream_codes: ["EtatCivil"])
  end

  it "rejects the accounts the export flags, is missing, has disabled, never activated or does not cover" do
    rows = described_class.call(
      users: users(
        {email: "introuvable@exemple.fr"},
        {email: "absent@exemple.fr"},
        {email: "desactive@exemple.fr"},
        {email: "inactif@exemple.fr"},
        {email: "autre@exemple.fr"}
      ),
      organizations:,
      keycloak: keycloak(
        {email: "introuvable@exemple.fr", anomalie: "introuvable"},
        {email: "desactive@exemple.fr", enabled: "false"},
        {email: "inactif@exemple.fr", required_actions: "UPDATE_PASSWORD"},
        {email: "autre@exemple.fr", user_type: "AUTRE"}
      )
    )

    expect(rows.map(&:status)).to all(eq("anomalie"))
    expect(rows.map(&:reason)).to eq([
      "export Keycloak : introuvable",
      "absent de l'export Keycloak",
      "compte Keycloak désactivé",
      "compte Keycloak jamais activé (UPDATE_PASSWORD)",
      "type Keycloak hors périmètre : AUTRE"
    ])
  end

  it "rejects a row without email, or whose organization identifiers are unusable" do
    rows = described_class.call(
      users: users(
        {email: ""},
        {email: "siret@exemple.fr", organization: "Commune Inconnue"},
        {email: "insee@exemple.fr", organization: "Commune Inconnue"}
      ),
      organizations:,
      keycloak: keycloak({email: "siret@exemple.fr", siret: "2126027420"}, {email: "insee@exemple.fr", branch_code: ""})
    )

    expect(rows.map(&:status)).to all(eq("anomalie"))
    expect(rows.map(&:reason)).to eq(["email manquant", "SIRET invalide : 2126027420", "code INSEE manquant"])
  end

  it "ignores the blank rows a spreadsheet export leaves behind" do
    rows = consolidate(users({}) + "\n,,,,,,,\n", keycloak({}))

    expect(rows.map(&:email)).to eq(["camille.martin@exemple.fr"])
  end

  it "rejects every occurrence of an email the spreadsheet lists twice, whatever its case" do
    rows = consolidate(users({}, {email: "Camille.Martin@exemple.fr", account_type: "ADM_LOC"}), keycloak({}))

    expect(rows.map(&:status)).to eq(%w[anomalie anomalie])
    expect(rows.map(&:reason)).to all(eq("email en double dans le tableur"))
  end

  it "rejects an unknown account type" do
    rows = consolidate(users({account_type: "super admin"}), keycloak({}))

    expect(rows.first.status).to eq("anomalie")
    expect(rows.first.reason).to eq("type de compte inconnu : super admin")
  end

  it "rejects an organization of the spreadsheet that differs from Keycloak's" do
    rows = consolidate(users({}), keycloak({branch_code: "26999"}))

    expect(rows.first.status).to eq("anomalie")
    expect(rows.first.reason).to eq("organisation du tableur (21260274200018/26274) ≠ Keycloak (21260274200018/26999)")
  end

  it "matches an organization whose quoted name holds a comma" do
    rows = consolidate(
      users({organization: "Syndicat des eaux, Exemple"}),
      keycloak({siret: "21260274200019", branch_code: "26275"})
    )

    expect(rows.first.status).to eq("injecté")
    expect(rows.first.entry).to include(siret: "21260274200019", insee_code: "26275")
  end

  it "falls back on Keycloak's organization when the spreadsheet name matches none" do
    rows = consolidate(users({organization: "Commune Inconnue"}), keycloak({branch_code: "26999"}))

    expect(rows.first.status).to eq("injecté")
    expect(rows.first.entry).to include(siret: "21260274200018", insee_code: "26999")
  end

  it "refuses a file whose header lacks an expected column" do
    expect {
      described_class.call(users: "Nom,Prénom,Adresse e-mail,Organisation\n", organizations:, keycloak: keycloak({}))
    }.to raise_error(ArgumentError, "colonnes manquantes : Type Utilisateur HubEE")
  end
end
