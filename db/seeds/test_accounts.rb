# frozen_string_literal: true

# Comptes de test du portail : ceux du poste de développement (`:local`) et ceux des
# environnements déployés de test, review app et recette (`:deployed`).
#
# Sous `db/`, hors autoload : chargé par `db/seeds.rb` seulement, rien en production ne le
# référence. Déclaratif et non destructif : ni agent, ni rattachement, ni trace d'accès n'est
# supprimé, seuls le rôle et les habilitations sont réalignés sur le catalogue.
module Seeds
  module TestAccounts
    # Le code INSEE est le piège : correct au login, il part en `code_insee` vers hub-api à
    # chaque appel. Un SIRET juste avec un INSEE faux donne un écran vide, sans erreur.
    ORGANIZATIONS = {
      # Environnements déployés : organisations réelles, connues de la V1 de recette.
      rochefourchat: {siret: "21260274200018", insee_code: "26274"}, # COMMUNE DE ROCHEFOURCHAT
      ain: {siret: "22010001000010", insee_code: "01053"}, # DEPARTEMENT DE L AIN
      # Poste de développement : codes INSEE fictifs, à la forme observée au référentiel V1.
      dinum: {siret: "13002526500013", insee_code: "00001"},
      lyon: {siret: "26690123100013", insee_code: "00002"},
      sardine: {siret: "84087593400027", insee_code: "00003"},
      # Code INSEE déclaré par le seed du socle : avec le 77372 des factories de la gem, la
      # liste des démarches restait vide.
      socle: {siret: "22770001000019", insee_code: "77001"}
    }.freeze

    # Les codes des flux sensibles ne sont pas dans ce dépôt public : le catalogue les désigne
    # par un symbole, résolu depuis l'environnement au semis. Des variables dédiées, et non
    # SENSITIVE_PROCESS_CODES que `SensitiveProcesses.parse` majuscule : l'habilitation part
    # verbatim vers l'amont, sensible à la casse, et un code recasé donne un écran vide.
    SENSITIVE_CODE_VARIABLES = {
      sensitive_1: "SEED_SENSITIVE_PROCESS_CODE_1",
      sensitive_2: "SEED_SENSITIVE_PROCESS_CODE_2"
    }.freeze

    Account = Data.define(:email, :first_name, :last_name, :organization, :role, :process_codes, :scope)

    # Une habilitation est soit un code public écrit verbatim, soit l'un des symboles ci-dessus.
    # Les habilitations bornent tout le monde, administrateur local compris ; le rôle ne tranche
    # que la liste vide — tout pour l'administrateur, rien pour le membre.
    ACCOUNTS = [
      # Environnements déployés : la matrice rôle × habilitation, sur une organisation réelle.
      Account.new(email: "membre-etatcivil@test.proconnect.gouv.fr", first_name: "Camille", last_name: "Membre",
        organization: :rochefourchat, role: "member", process_codes: ["EtatCivil"], scope: :deployed),
      Account.new(email: "membre-sensible@test.proconnect.gouv.fr", first_name: "Dominique", last_name: "Sensible",
        organization: :rochefourchat, role: "member", process_codes: [:sensitive_1], scope: :deployed),
      Account.new(email: "admin-total@test.proconnect.gouv.fr", first_name: "Alex", last_name: "Total",
        organization: :rochefourchat, role: "local_administrator", process_codes: [], scope: :deployed),
      Account.new(email: "admin-etatcivil@test.proconnect.gouv.fr", first_name: "Sacha", last_name: "Borne",
        organization: :rochefourchat, role: "local_administrator", process_codes: ["EtatCivil"], scope: :deployed),
      Account.new(email: "admin-sensible@test.proconnect.gouv.fr", first_name: "Claude", last_name: "Sensible",
        organization: :rochefourchat, role: "local_administrator", process_codes: [:sensitive_1], scope: :deployed),
      Account.new(email: "marie.durand@basrec.hubee.numerique.gouv.fr", first_name: "Marie", last_name: "Durand",
        organization: :rochefourchat, role: "local_administrator", process_codes: [], scope: :deployed),
      Account.new(email: "jean.dupont@basrec.hubee.numerique.gouv.fr", first_name: "Jean", last_name: "Dupont",
        organization: :ain, role: "member", process_codes: [:sensitive_2], scope: :deployed),
      Account.new(email: "marie.dupont@basrec.hubee.numerique.gouv.fr", first_name: "Marie", last_name: "Dupont",
        organization: :rochefourchat, role: "member", process_codes: ["EtatCivil", "recensementCitoyen"], scope: :deployed),

      # Poste de développement : les comptes réels des fournisseurs d'identité de test ProConnect,
      # userN@yopmail.com (ProConnect Identité), identités libres de FIA1 (@test.proconnect.gouv.fr,
      # SIRET saisissable), et le compte du FI ANCT.
      Account.new(email: "user@yopmail.com", first_name: "Camille", last_name: "Ordinaire",
        organization: :dinum, role: "member", process_codes: [], scope: :local),
      Account.new(email: "user1@yopmail.com", first_name: "Alex", last_name: "Admin",
        organization: :dinum, role: "local_administrator", process_codes: [], scope: :local),
      Account.new(email: "user2@yopmail.com", first_name: "Dominique", last_name: "Habilite",
        organization: :dinum, role: "member", process_codes: [:sensitive_1], scope: :local),
      Account.new(email: "user3@yopmail.com", first_name: "Sacha", last_name: "Ailleurs",
        organization: :lyon, role: "member", process_codes: [], scope: :local),
      Account.new(email: "agent@test.proconnect.gouv.fr", first_name: "Camille", last_name: "Fia",
        organization: :dinum, role: "member", process_codes: [], scope: :local),
      Account.new(email: "admin@test.proconnect.gouv.fr", first_name: "Alex", last_name: "Fia",
        organization: :dinum, role: "local_administrator", process_codes: [], scope: :local),
      Account.new(email: "sensible@test.proconnect.gouv.fr", first_name: "Dominique", last_name: "Fia",
        organization: :dinum, role: "member", process_codes: [:sensitive_1], scope: :local),
      Account.new(email: "bastien.ogier@sardinepq.fr", first_name: "Bastien", last_name: "Ogier",
        organization: :sardine, role: "local_administrator", process_codes: [], scope: :local),
      # Membre et non administrateur local, pour que le filtrage par habilitation soit traversé
      # sur les deux démarches en accès portail du socle.
      Account.new(email: "socle@test.proconnect.gouv.fr", first_name: "Camille", last_name: "Socle",
        organization: :socle, role: "member", process_codes: %w[CERTDC EtatCivil], scope: :local)
    ].freeze

    class << self
      def accounts(scopes) = ACCOUNTS.select { |account| scopes.include?(account.scope) }

      # Ce que les comptes retenus attendent de l'environnement, et qu'il ne déclare pas.
      def missing_variables(scopes)
        accounts(scopes).flat_map(&:process_codes).grep(Symbol).uniq
          .map { |code| SENSITIVE_CODE_VARIABLES.fetch(code) }
          .reject { |name| ENV[name].present? }
      end

      # Renvoie les rattachements écrits, dans l'ordre du catalogue, pour que l'appelant en rende
      # compte. Les comptes dont un code sensible manque en sont absents.
      def apply!(scopes)
        accounts(scopes).filter_map do |account|
          process_codes = resolve_process_codes(account.process_codes)
          next if process_codes.nil?

          # `provider_sub` reste nul : c'est ProConnect qui scelle l'identité au premier login.
          agent = Agent.find_or_create_by!(email: account.email) do |new_agent|
            new_agent.first_name = account.first_name
            new_agent.last_name = account.last_name
          end

          # `update!` séparé : le bloc de `find_or_create_by!` ne tourne pas sur un existant.
          membership = Membership.find_or_create_by!(agent:, organization_link: link_for(account.organization))
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

      # Par compte et non d'un bloc : seules les organisations des comptes retenus doivent naître.
      def link_for(organization) = OrganizationLink.find_or_create_by!(**ORGANIZATIONS.fetch(organization))

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
