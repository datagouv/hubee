CI.run("Hubee CI", "Plateforme SecNumCloud") do
  # db:schema:load est plus rapide que db:migrate en CI (pas d'historique à rejouer).
  # Si bin/setup est modifié, vérifier que ce step reste cohérent.
  # db:seed exclu du Setup : les specs supposent une base vide (contain_exactly, SIRETs hardcodés).
  # Les seeds sont validés en fin de CI via db:seed:replant (Tests: Seeds).
  step "Setup", "env RAILS_ENV=test bin/rails db:drop db:create db:schema:load"

  step "Style: Ruby", "bundle exec standardrb --no-fix"

  step "Security: Gems", "bin/bundler-audit"
  step "Security: Code", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Security: Importmap", "bin/importmap audit"

  step "Tests: RSpec with Coverage", "env COVERAGE=true bundle exec rspec --format progress"
  step "Tests: E2E", "bundle exec cucumber"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  if success?
    echo "All checks passed! Coverage >= 90%. Ready for merge.", type: :success
    step "Signoff: Mark commit as approved", "gh signoff" unless ENV["SKIP_SIGNOFF"]
  else
    failure "CI Failed", "Fix the issues above and run bin/ci again"
  end
end
