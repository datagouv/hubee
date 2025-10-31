# frozen_string_literal: true

namespace :security do
  desc "Run all security checks (bundler-audit + brakeman)"
  task all: [:bundler_audit, :brakeman]

  desc "Check for vulnerable gem dependencies"
  task :bundler_audit do
    puts "🔍 Running bundler-audit..."
    puts ""

    # Update advisory database
    sh "bundle exec bundler-audit update" do |ok, _res|
      puts "⚠️  Failed to update advisory database" unless ok
    end

    # Run audit
    sh "bundle exec bundler-audit check" do |ok, res|
      if ok
        puts ""
        puts "✅ No vulnerable dependencies found!"
      else
        puts ""
        puts "❌ Vulnerable dependencies detected!"
        exit res.exitstatus
      end
    end
  end

  desc "Run Brakeman security scanner"
  task :brakeman do
    puts "🔍 Running Brakeman..."
    puts ""

    sh "bundle exec brakeman --quiet --no-pager" do |ok, res|
      if ok
        puts ""
        puts "✅ No security issues found!"
      else
        puts ""
        puts "❌ Security issues detected!"
        exit res.exitstatus
      end
    end
  end
end

# Alias pour commodité
desc "Run security checks (alias for security:all)"
task security: "security:all"
