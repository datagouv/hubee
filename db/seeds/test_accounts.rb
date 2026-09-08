# frozen_string_literal: true

# Comptes de test du portail, semés en review app et en recette.
#
# Volontairement hors des quatre namespaces de l'application : ce fichier vit sous `db/`, qui
# n'est ni autoloadé ni eager-loadé. Rien en production ne le référence — il est chargé par
# `lib/tasks/portail.rake` et par `db/seeds.rb`, et lui-même ne référence que les modèles.
#
# Déclaratif : ce qui est listé fait foi. Non destructif : ni agent, ni rattachement, ni trace
# d'accès n'est supprimé — seuls le rôle et les habilitations sont réalignés sur le catalogue.
module Seeds
  module TestAccounts
    # Le nom de l'organisation ne vit qu'en commentaire : `OrganizationLink` n'en porte aucun,
    # le libellé est lu en direct dans le référentiel V1.
    #
    # Le code INSEE est le piège : correct au login, il part en `code_insee` vers hub-api à
    # chaque appel. Un SIRET juste avec un INSEE faux donne un écran vide, sans erreur.
    ORGANIZATIONS = {
      rochefourchat: {siret: "21260274200018", insee_code: "26274"}, # COMMUNE DE ROCHEFOURCHAT
      ain: {siret: "22010001000010", insee_code: "01053"} # DEPARTEMENT DE L AIN
    }.freeze

    # Les codes des flux sensibles ne sont pas dans ce dépôt, qui est public : le catalogue les
    # désigne par un symbole, résolu depuis l'environnement au moment du semis.
    #
    # Des variables dédiées, et non `SENSITIVE_PROCESS_CODES` : deux comparaisons se font sur un
    # code de flux, et une seule ignore la casse.
    #
    #   - La MFA l'ignore : `SensitiveProcesses.parse` rabat la liste en majuscules, et
    #     `SecondFactor` compare en `UPPER()` des deux côtés.
    #   - Le périmètre compare caractère pour caractère : l'habilitation est stockée verbatim
    #     (`ProcessAccess` ne fait que `strip`), puis part telle quelle en filtre vers l'amont
    #     et repasse par le `include?` de `ProcessPerimeter.covers?`, liste comme détail.
    #
    # Semer l'habilitation depuis `SENSITIVE_PROCESS_CODES`, déjà majusculée, écrirait donc
    # `GRAND_CODE` là où l'amont connaît `GrandCode`. La connexion passerait — le login ne
    # regarde que le SIRET — la MFA se déclencherait, et l'écran des démarches resterait vide
    # sans message d'erreur. C'est le symptôme le plus coûteux à diagnostiquer.
    SENSITIVE_CODE_VARIABLES = {
      sensitive_1: "SEED_SENSITIVE_PROCESS_CODE_1",
      sensitive_2: "SEED_SENSITIVE_PROCESS_CODE_2"
    }.freeze

    Account = Data.define(:email, :first_name, :last_name, :organization, :role, :process_codes)

    # Une habilitation est soit un code public écrit verbatim, soit l'un des symboles ci-dessus.
    # Les habilitations bornent tout le monde, administrateur local compris ; le rôle ne tranche
    # que la liste vide — tout pour l'administrateur, rien pour le membre.
    ACCOUNTS = [
      Account.new(email: "membre-etatcivil@test.proconnect.gouv.fr", first_name: "Camille", last_name: "Membre",
        organization: :rochefourchat, role: "member", process_codes: ["EtatCivil"]),
      Account.new(email: "membre-sensible@test.proconnect.gouv.fr", first_name: "Dominique", last_name: "Sensible",
        organization: :rochefourchat, role: "member", process_codes: [:sensitive_1]),
      Account.new(email: "admin-total@test.proconnect.gouv.fr", first_name: "Alex", last_name: "Total",
        organization: :rochefourchat, role: "local_administrator", process_codes: []),
      Account.new(email: "admin-etatcivil@test.proconnect.gouv.fr", first_name: "Sacha", last_name: "Borne",
        organization: :rochefourchat, role: "local_administrator", process_codes: ["EtatCivil"]),
      Account.new(email: "admin-sensible@test.proconnect.gouv.fr", first_name: "Claude", last_name: "Sensible",
        organization: :rochefourchat, role: "local_administrator", process_codes: [:sensitive_1]),
      Account.new(email: "marie.durand@basrec.hubee.numerique.gouv.fr", first_name: "Marie", last_name: "Durand",
        organization: :rochefourchat, role: "local_administrator", process_codes: []),
      Account.new(email: "jean.dupont@basrec.hubee.numerique.gouv.fr", first_name: "Jean", last_name: "Dupont",
        organization: :ain, role: "member", process_codes: [:sensitive_2]),
      Account.new(email: "marie.dupont@basrec.hubee.numerique.gouv.fr", first_name: "Marie", last_name: "Dupont",
        organization: :rochefourchat, role: "member", process_codes: ["EtatCivil", "recensementCitoyen"])
    ].freeze

    class << self
      # Le semis local ne pose pas ces comptes : ils visent des organisations que le socle de
      # développement ne connaît pas. Seuls les environnements déployés de test les demandent, en
      # posant cette variable — la recette tourne en `production`, c'est la seule chose qui l'en
      # distingue, et l'outillage de déploiement ne doit jamais la poser en production.
      def requested? = ENV["SEED_TEST_ACCOUNTS"] == "true"

      # Ce que l'environnement ne déclare pas, et que l'appelant doit donc signaler.
      def missing_variables = SENSITIVE_CODE_VARIABLES.values.reject { |name| ENV[name].present? }

      # Renvoie les rattachements écrits, dans l'ordre du catalogue, pour que l'appelant en rende
      # compte. Les comptes dont un code sensible manque en sont absents.
      def apply!
        links = ORGANIZATIONS.transform_values { |attributes| OrganizationLink.find_or_create_by!(**attributes) }

        ACCOUNTS.filter_map do |account|
          process_codes = resolve_process_codes(account.process_codes)
          next if process_codes.nil?

          # `provider_sub` reste nul : c'est ProConnect qui scelle l'identité au premier login.
          agent = Agent.find_or_create_by!(email: account.email) do |new_agent|
            new_agent.first_name = account.first_name
            new_agent.last_name = account.last_name
          end

          # `update!` séparé : le bloc de `find_or_create_by!` ne tourne pas sur un existant.
          membership = Membership.find_or_create_by!(agent:, organization_link: links.fetch(account.organization))
          membership.update!(role: account.role)
          align_process_accesses(membership, process_codes)
          membership
        end
      end

      # Ce que le semis a produit, et non ce qu'il visait : un `voit rien` signale une habilitation
      # qui n'a pas été écrite, un `sans MFA` inattendu un code absent de SENSITIVE_PROCESS_CODES.
      def report(memberships)
        memberships.map do |membership|
          [
            membership.agent.email.ljust(45),
            membership.role.ljust(20),
            (Portail::Access::SecondFactor.required_for?(membership) ? "MFA requise" : "sans MFA").ljust(12),
            perimeter_of(membership)
          ].join(" ")
        end
      end

      private

      def perimeter_of(membership)
        if Portail::Access::ProcessPerimeter.unrestricted?(membership)
          "voit tout"
        elsif Portail::Access::ProcessPerimeter.none?(membership)
          "voit rien"
        else
          "limité à #{membership.process_codes.join(", ")}"
        end
      end

      # `nil` dès qu'un code sensible manque : mieux vaut laisser le compte de côté que l'enrôler
      # sur un périmètre faux, que personne ne saurait distinguer d'un défaut d'habilitation.
      def resolve_process_codes(declared)
        declared.map do |code|
          next code if code.is_a?(String)

          value = ENV[SENSITIVE_CODE_VARIABLES.fetch(code)]
          return nil if value.blank?

          value.strip
        end
      end

      # `where.not(process_code: [])` vaut `1=1` : un compte déclaré sans habilitation perd bien
      # toutes les siennes.
      def align_process_accesses(membership, process_codes)
        membership.process_accesses.where.not(process_code: process_codes).destroy_all
        process_codes.each { |process_code| ProcessAccess.find_or_create_by!(membership:, process_code:) }
      end
    end
  end
end
