# frozen_string_literal: true

namespace :test_accounts do
  desc "Enrôler les comptes de test d'une boîte personnelle sur Rochefourchat (ex. : bin/rails \"test_accounts:personal[prenom.nom@numerique.gouv.fr]\")"
  task :personal, [:email] => :environment do |_task, args|
    # Même garde que les comptes déployés de `db:seed` : la recette tourne en production.
    unless Rails.env.local? || ENV["SEED_TEST_ACCOUNTS"] == "true"
      abort "❌ Comptes de test refusés hors développement, test, review app et recette (SEED_TEST_ACCOUNTS)"
    end

    require Rails.root.join("db/seeds/test_accounts")

    accounts = Seeds::TestAccounts.personal_accounts(args[:email])
    memberships = Seeds::TestAccounts.enrol!(accounts)
    puts Seeds::TestAccounts.report(memberships)

    missing = Seeds::TestAccounts.missing_variables_for(accounts)
    if missing.any?
      puts "⚠️  #{missing.join(", ")} absente(s) : #{accounts.size - memberships.size} compte(s) sensible(s) non enrôlé(s)"
    end

    puts "✅ #{memberships.size} comptes de test enrôlés"
  end
end
