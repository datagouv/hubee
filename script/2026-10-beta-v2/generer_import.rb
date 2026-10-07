# frozen_string_literal: true

# Opération ponctuelle bêta V2 (octobre 2026), non maintenue — procédure dans le README voisin.
require "csv"
require "fileutils"
require "json"
require_relative "consolidation"

module Portail
  module BetaImport
    module Output
      BATCH_SIZE = 15

      class << self
        def report(rows)
          CSV.generate(col_sep: ";", quote_empty: false) do |csv|
            csv << %w[email injecte statut raison]
            rows.each { |row| csv << [row.email, row.entry ? "oui" : "non", row.status, row.reason] }
          end
        end

        # Les valeurs voyagent en JSON dans un heredoc non interpolé : un `'` ou un `#{` venu d'un CSV
        # ne devient jamais du code exécuté en console.
        def batches(rows)
          rows.filter_map(&:entry).each_slice(BATCH_SIZE).map do |entries|
            [
              %(require Rails.root.join("script/2026-10-beta-v2/importer_agents").to_s),
              "Portail::BetaImport::Importer.call(<<~'JSON')",
              "[",
              entries.map(&:to_json).join(",\n"),
              "]",
              "JSON",
              ""
            ].join("\n")
          end
        end
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  *sources, output = ARGV
  abort "usage : ruby #{__FILE__} utilisateurs.csv organisations.csv keycloak.csv DOSSIER_DE_SORTIE" unless sources.size == 3

  repository = File.expand_path("../..", __dir__)
  output = File.expand_path(output)
  if "#{output}/".start_with?("#{repository}/") && !output.start_with?("#{repository}/tmp/")
    abort "Sortie refusée : données personnelles, à écrire hors du dépôt, ou sous tmp/."
  end

  users, organizations, keycloak = sources.map { |path| File.read(path, encoding: "bom|utf-8") }
  rows = Portail::BetaImport::Consolidation.call(users:, organizations:, keycloak:)

  FileUtils.mkdir_p(output)
  File.write(File.join(output, "rapport.csv"), Portail::BetaImport::Output.report(rows))
  Portail::BetaImport::Output.batches(rows).each.with_index(1) do |batch, index|
    File.write(File.join(output, format("lot-%02d.txt", index)), batch)
  end
  rows.group_by(&:status).each { |status, group| puts "#{status} : #{group.size}" }
end
