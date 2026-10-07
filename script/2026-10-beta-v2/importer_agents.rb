# frozen_string_literal: true

# Opération ponctuelle bêta V2 (octobre 2026), non maintenue — procédure dans le README voisin.
# Chargé à la main en console par les lots du générateur, jamais par l'application.
require "digest"
require "json"

module Portail
  module BetaImport
    module Importer
      Result = Data.define(:email, :membership, :changes, :error)

      class << self
        # L'empreinte prouve que recette et production ont exécuté le même fichier : le conteneur
        # n'expose aucune révision git.
        def call(json, io: $stdout)
          io.puts "#{File.basename(__FILE__)} sha256 #{Digest::SHA256.file(__FILE__).hexdigest}"
          JSON.parse(json).each { |entry| io.puts line(import(entry)) }
          nil
        end

        def import(entry)
          changes = []
          # Point de sauvegarde : sous `console --sandbox`, déjà dans une transaction, une entrée en
          # échec ne doit rien laisser derrière elle.
          membership = ApplicationRecord.transaction(requires_new: true) do
            agent = Agent.find_or_create_by!(email: entry.fetch("email")) do |created|
              created.first_name = entry["first_name"].presence
              created.last_name = entry["last_name"].presence
              changes << "agent créé"
            end
            link = OrganizationLink.find_or_create_by!(siret: entry.fetch("siret"), insee_code: entry.fetch("insee_code"))
            membership = Membership.find_or_initialize_by(agent:, organization_link: link)

            if membership.new_record?
              changes << "rattachement créé"
            elsif membership.role != entry.fetch("role")
              changes << "rôle #{membership.role} → #{entry.fetch("role")}"
            end

            membership.update!(role: entry.fetch("role"))
            changes.concat(align_data_stream_accesses(membership, entry.fetch("data_stream_codes")))
            membership
          end

          Result.new(email: entry.fetch("email"), membership:, changes:, error: nil)
        rescue ActiveRecord::RecordInvalid => error
          Result.new(email: entry.fetch("email"), membership: nil, changes: [], error: error.message)
        end

        private

        def align_data_stream_accesses(membership, codes)
          current = membership.data_stream_accesses.pluck(:data_stream_code)
          removed = current - codes
          added = codes - current

          membership.data_stream_accesses.where(data_stream_code: removed).destroy_all
          added.each { |code| membership.data_stream_accesses.create!(data_stream_code: code) }
          removed.map { |code| "− #{code}" } + added.map { |code| "+ #{code}" }
        end

        def line(result)
          return [result.email, "ERREUR", result.error].join(" | ") if result.error

          membership = result.membership.reload
          [
            result.email,
            membership.role,
            Portail::Access::SecondFactor.required_for?(membership) ? "MFA requise" : "sans MFA",
            perimeter(membership),
            result.changes.empty? ? "inchangé" : result.changes.join(", ")
          ].join(" | ")
        end

        def perimeter(membership)
          if Portail::Access::DataStreamPerimeter.unrestricted?(membership)
            "voit tout"
          elsif Portail::Access::DataStreamPerimeter.none?(membership)
            "voit rien"
          else
            "limité à #{membership.data_stream_codes.join(", ")}"
          end
        end
      end
    end
  end
end
