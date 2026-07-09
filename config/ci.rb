CI.run("Hubee CI", "Plateforme SecNumCloud") do
  # Steps statiques : ni boot de l'app, ni base de données, ni gem privée hub_api_v1.
  # Seuls ceux-ci tournent sur la CI GitHub Actions (CI_STATIC_ONLY=true), où la source
  # GitLab de la gem privée est injoignable (cf. Gemfile / config/application.rb).
  step "Style: Ruby", "bundle exec standardrb --no-fix"

  step "Security: Gems", "bin/bundler-audit"
  step "Security: Code", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Importmap", "bin/importmap audit"

  # Steps dynamiques : bootent l'app (donc requièrent la gem privée) et/ou la base.
  # Skippés quand CI_STATIC_ONLY est défini ; exécutés en local (les devs ont la gem).
  unless ENV["CI_STATIC_ONLY"]
    # db:schema:load est plus rapide que db:migrate en CI (pas d'historique à rejouer).
    # Si bin/setup est modifié, vérifier que ce step reste cohérent.
    # db:seed exclu du Setup : les specs supposent une base vide (contain_exactly, SIRETs hardcodés).
    # Les seeds sont validés en fin de CI via db:seed:replant (Tests: Seeds).
    step "Setup", "env RAILS_ENV=test bin/rails db:drop db:create db:schema:load"

    step "Tests: RSpec with Coverage", "env COVERAGE=true bundle exec rspec --format progress"
    step "Tests: E2E", "bundle exec cucumber"
    step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
  end
end
