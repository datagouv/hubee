# frozen_string_literal: true

# Configuration de strong_migrations pour PostgreSQL 18
# Documentation : https://github.com/ankane/strong_migrations

# Mark existing migrations as safe (ne pas analyser les migrations précédentes)
# Dernière migration validée : CreateDataStreams (20251028002505)
StrongMigrations.start_after = 20251028002505

# Set timeouts for migrations
# Important pour éviter les locks prolongés en production
# ⚠️  Si vous utilisez PgBouncer en mode transaction, configurez ces timeouts au niveau user/database
StrongMigrations.lock_timeout = 10.seconds      # Temps max pour acquérir un lock
StrongMigrations.statement_timeout = 1.hour     # Temps max d'exécution d'une migration

# Set the version of the production database
# PostgreSQL 18 supporte nativement de nombreuses opérations sûres
StrongMigrations.target_version = 18

# Analyze tables after indexes are added
# Les statistiques à jour améliorent les performances du query planner
StrongMigrations.auto_analyze = true

# Make some operations safe by default (PostgreSQL 11+)
# Recommandé pour PostgreSQL 18 : évite les faux positifs
StrongMigrations.safe_by_default = true

# Alphabetize schema (optionnel mais recommandé pour des diffs propres)
StrongMigrations.alphabetize_schema = true

# Check down method presence (optionnel mais recommandé)
# Force l'écriture de migrations réversibles
# StrongMigrations.check_down = true

# Target SQL mode (optionnel, utile pour CI/staging)
# Affiche le SQL à exécuter au lieu d'erreur
# StrongMigrations.target_sql_mode = :make_safe

# Remove invalid indexes when rerunning migrations
# Utile en développement pour nettoyer les indexes cassés
StrongMigrations.remove_invalid_indexes = true

# Checks personnalisés pour Hubee (décommenter si besoin)
# StrongMigrations.add_check do |method, args|
#   # Example : Interdire les indexes sur la table organizations (si elle devient trop grosse)
#   if method == :add_index && args[0].to_s == "organizations"
#     stop! "Use add_index :organizations, algorithm: :concurrently for large tables"
#   end
# end
