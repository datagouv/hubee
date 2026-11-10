# frozen_string_literal: true

require "rails_helper"

# Le portail obtient ses jetons hub-api en envoyant le secret de son client dans le corps de la
# requête. Sentry joint à chaque erreur les requêtes HTTP sortantes de la requête en cours : il ne
# doit jamais en garder le corps. Ce garde-fou échoue si un réglage de collecte vient à l'ouvrir.
RSpec.describe "Sentry initializer" do
  around do |example|
    original_dsn = ENV["SENTRY_DSN"]
    ENV["SENTRY_DSN"] = "https://public@sentry.example/1"
    example.run
  ensure
    original_dsn.nil? ? ENV.delete("SENTRY_DSN") : ENV["SENTRY_DSN"] = original_dsn
  end

  it "never collects outgoing HTTP bodies nor personal data" do
    config = Sentry::Configuration.new
    expect(Sentry).to receive(:init).and_yield(config)

    load Rails.root.join("config/initializers/sentry.rb")

    expect(config.send_default_pii).to be(false)
    expect(config.data_collection.collect_outgoing_http_body?).to be(false)
    expect(config.data_collection.collect_incoming_http_body?).to be(false)
    expect(config.data_collection.collect_stack_frame_variables?).to be(false)
  end
end
