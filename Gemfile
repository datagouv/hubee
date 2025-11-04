source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.0"
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
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Authorization with Pundit [https://github.com/varvet/pundit]
gem "pundit", "~> 2.4"

# Pagination for API [https://github.com/ddnexus/pagy]
gem "pagy", "~> 43.0"

# State machine for model workflows [https://github.com/aasm/aasm]
gem "aasm", "~> 5.5"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Catch unsafe database migrations [https://github.com/ankane/strong_migrations]
  gem "strong_migrations"

  # Ruby style guide, linter, and formatter [https://github.com/standardrb/standard]
  gem "standard", require: false

  # RSpec for unit and request testing [https://rspec.info/]
  gem "rspec-rails", "~> 8.0"

  # Test data factories [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails", "~> 6.4"

  # Fake data generation [https://github.com/faker-ruby/faker]
  gem "faker", "~> 3.5"
end

group :test do
  # Code coverage analysis [https://github.com/simplecov-ruby/simplecov]
  gem "simplecov", require: false

  # Cucumber for BDD E2E testing [https://cucumber.io/]
  gem "cucumber-rails", require: false
  gem "database_cleaner-active_record"

  # Additional test helpers
  gem "shoulda-matchers", "~> 7.0"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
