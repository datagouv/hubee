source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Frontend : DSFR (Design System de l'État) via gems — pas de npm (réduction surface supply chain)
gem "dsfr-assets"
gem "dsfr-form_builder"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt"

# Authorization with Pundit [https://github.com/varvet/pundit]
# gem "pundit"

# Pagination for API [https://github.com/ddnexus/pagy]
gem "pagy"

# State machine for model workflows [https://github.com/aasm/aasm]
gem "aasm"

# Business logic interactors [https://github.com/collectiveidea/interactor]
gem "interactor"

# Error monitoring [https://github.com/getsentry/sentry-ruby]
gem "sentry-ruby"
gem "sentry-rails"

# Client API Hubee V1 (gem privée)
# Groupe dédié (hors default) pour pouvoir l'exclure du bundle via BUNDLE_WITHOUT=hub_api_v1
# là où la source GitLab privée est injoignable — ex. CI GitHub Actions (analyse statique +
# sécurité). Conséquence : la gem n'est pas auto-requise par Bundler.require ; la requérir
# explicitement à l'endroit qui la consomme.
group :hub_api_v1 do
  gem "hub-api-v1", git: "https://gitlab.hubee.numerique.gouv.fr/hubee/v2/hub-api-v1.git", tag: "1.1.1", require: "hub_api_v1"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Catch unsafe database migrations [https://github.com/ankane/strong_migrations]
# Chargée dans tous les environnements : l'entrypoint Docker joue db:prepare en
# production, les checks doivent donc protéger aussi les migrations prod — et
# l'initializer référence la constante à chaque boot, y compris en prod.
gem "strong_migrations"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Ruby style guide, linter, and formatter [https://github.com/standardrb/standard]
  gem "standard", require: false

  # RSpec for unit and request testing [https://rspec.info/]
  gem "rspec-rails"

  # Test data factories [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"

  # Fake data generation [https://github.com/faker-ruby/faker]
  gem "faker"
end

group :test do
  # Code coverage analysis [https://github.com/simplecov-ruby/simplecov]
  gem "simplecov", require: false

  # Cucumber for BDD E2E testing [https://cucumber.io/]
  gem "cucumber-rails", require: false
  gem "database_cleaner-active_record"

  # Additional test helpers
  gem "shoulda-matchers"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
