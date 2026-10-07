# frozen_string_literal: true

# Opération ponctuelle bêta V2 (octobre 2026), non maintenue — procédure dans le README voisin.
# Sans ActiveSupport : le générateur tourne avec `ruby` seul.
require "csv"

module Portail
  module BetaImport
    module Consolidation
      USERS_COLUMNS = {
        email: "Adresse e-mail", account_type: "Type Utilisateur HubEE", organization: "Organisation",
        first_name: "Prénom", last_name: "Nom"
      }.freeze
      ORGANIZATIONS_COLUMNS = {name: "Organisation", siret: "CompanyRegister", insee_code: "BranchCode"}.freeze
      KEYCLOAK_COLUMNS = %w[
        email keycloak_id enabled required_actions first_name last_name user_type siret branch_code
        organization_name unrestricted process_code process_status anomalie
      ].freeze

      ROLES = {
        "agt" => "member",
        "agent" => "member",
        "adm_loc" => "local_administrator",
        "admin local" => "local_administrator",
        "administrateur local" => "local_administrator"
      }.freeze
      USER_TYPES = %w[AGT ADM_LOC].freeze
      # Seule anomalie d'export qui laisse la ligne complète : le code INSEE déduit sans ambiguïté.
      RESOLVED_EXPORT_ANOMALY = "branch_code_resolu"
      SIRET_FORMAT = /\A\d{14}\z/

      Row = Data.define(:email, :status, :reason, :entry)

      class Anomaly < StandardError; end

      class << self
        def call(users:, organizations:, keycloak:)
          user_rows = parse(users, USERS_COLUMNS.values)
          organizations_by_name = parse(organizations, ORGANIZATIONS_COLUMNS.values)
            .group_by { |row| normalize(row[ORGANIZATIONS_COLUMNS[:name]]) }
          accounts_by_email = parse(keycloak, KEYCLOAK_COLUMNS).group_by { |row| row["email"].downcase }
          emails = user_rows.map { |user| user[USERS_COLUMNS[:email]].downcase }

          user_rows.zip(emails).map do |user, email|
            consolidate(user, email, emails.count(email) > 1, organizations_by_name, accounts_by_email.fetch(email, []))
          rescue Anomaly => anomaly
            Row.new(email:, status: "anomalie", reason: anomaly.message, entry: nil)
          end
        end

        private

        # Les tableurs sortent en `,`, l'export Keycloak en `;`. Les lignes vides d'un tableur sont ignorées.
        def parse(text, columns)
          first_line = text.each_line.first.to_s
          col_sep = (first_line.count(";") > first_line.count(",")) ? ";" : ","
          missing = columns - CSV.parse_line(first_line, col_sep:).to_a.map { |header| header.to_s.strip }
          raise ArgumentError, "colonnes manquantes : #{missing.join(", ")}" if missing.any?

          CSV.parse(text, headers: true, col_sep:, header_converters: ->(header) { header.to_s.strip })
            .map { |row| stripped(row) }
            .reject { |row| row.values.all?(&:empty?) }
        end

        def stripped(row) = row.to_h.transform_values { |value| value.to_s.strip }

        def normalize(text) = text.squeeze(" ").downcase

        def consolidate(user, email, duplicated, organizations, account_rows)
          raise Anomaly, "email manquant" if email.empty?
          raise Anomaly, "email en double dans le tableur" if duplicated

          account_type = user[USERS_COLUMNS[:account_type]]
          role = ROLES.fetch(normalize(account_type)) { raise Anomaly, "type de compte inconnu : #{account_type}" }
          account = account(account_rows)
          siret, insee_code = organization(user[USERS_COLUMNS[:organization]], organizations, account)
          granted = process_codes(account_rows, "retenu")
          dropped = process_codes(account_rows, "hors_abonnement")

          if role == "local_administrator" && granted.empty? && dropped.any?
            raise Anomaly, "admin local dont tous les process sont hors abonnement : il verrait tout"
          end

          entry = {
            email:,
            first_name: first_filled(user[USERS_COLUMNS[:first_name]], account["first_name"]),
            last_name: first_filled(user[USERS_COLUMNS[:last_name]], account["last_name"]),
            siret:, insee_code:, role:, data_stream_codes: granted
          }

          if role == "member" && granted.empty?
            Row.new(email:, status: "avertissement", reason: "ne verra rien : #{blindness(account, dropped)}", entry:)
          else
            reason = dropped.any? ? "process hors abonnement retirés : #{dropped.join(", ")}" : ""
            Row.new(email:, status: "injecté", reason:, entry:)
          end
        end

        def account(rows)
          raise Anomaly, "absent de l'export Keycloak" if rows.empty?

          # Plusieurs anomalies d'un même compte sont jointes par `|`.
          flagged = rows.flat_map { |row| row["anomalie"].split("|") }.reject { |value| value == RESOLVED_EXPORT_ANOMALY }
          raise Anomaly, "export Keycloak : #{flagged.uniq.join(", ")}" if flagged.any?

          account = rows.first
          raise Anomaly, "compte Keycloak désactivé" unless account["enabled"] == "true"
          raise Anomaly, "compte Keycloak jamais activé (#{account["required_actions"]})" unless account["required_actions"].empty?
          raise Anomaly, "type Keycloak hors périmètre : #{account["user_type"]}" unless USER_TYPES.include?(account["user_type"])

          account
        end

        # Le tableur contrôle l'organisation de Keycloak : un rattachement faux exposerait les télédossiers d'une autre.
        def organization(name, organizations, account)
          from_keycloak = [account["siret"], account["branch_code"]]
          matches = organizations.fetch(normalize(name), []).map do |row|
            [row[ORGANIZATIONS_COLUMNS[:siret]].delete(" "), row[ORGANIZATIONS_COLUMNS[:insee_code]]]
          end.uniq

          if matches.one? && matches.first != from_keycloak
            raise Anomaly, "organisation du tableur (#{matches.first.join("/")}) ≠ Keycloak (#{from_keycloak.join("/")})"
          end

          siret, insee_code = from_keycloak
          raise Anomaly, "SIRET invalide : #{siret}" unless SIRET_FORMAT.match?(siret)
          raise Anomaly, "code INSEE manquant" if insee_code.empty?

          [siret, insee_code]
        end

        def first_filled(*values) = values.find { |value| !value.empty? }

        def process_codes(rows, status)
          rows.select { |row| row["process_status"] == status }.map { |row| row["process_code"] }.reject(&:empty?).uniq
        end

        def blindness(account, dropped)
          if dropped.any?
            "process tous hors abonnement (#{dropped.join(", ")})"
          elsif account["user_type"] == "ADM_LOC"
            "admin local sans process dans Keycloak, agent dans le tableur"
          else
            "aucun process dans Keycloak"
          end
        end
      end
    end
  end
end
