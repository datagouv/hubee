CI.run("Hubee CI", "Plateforme SecNumCloud") do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bundle exec standardrb"

  step "Security: Gems", "bin/bundler-audit check --update"
  step "Security: Code", "bin/brakeman --quiet --no-pager --exit-on-warn"
  step "Security: Importmap", "bin/importmap audit"

  step "Database: Prepare", "bin/rails db:test:prepare"

  step "Tests: RSpec with Coverage", "env COVERAGE=true bundle exec rspec --format progress"
  step "Tests: E2E", "bundle exec cucumber"

  if success?
    echo "All checks passed! Coverage >= 80%. Ready for merge.", type: :success
    step "Signoff: Mark commit as approved", "gh signoff"
  else
    failure "CI Failed", "Fix the issues above and run bin/ci again"
  end
end
