# frozen_string_literal: true

# Les erreurs telles que la production les rend : en test, Rails lève les exceptions imprévues et
# affiche sa page de débogage ; en production, toute exception passe par config.exceptions_app.
module ProductionExceptions
  Collector = Struct.new(:errors) do
    def report(error, **) = errors << error
  end

  # Ce que reçoit le rapporteur de Rails, auquel Sentry est abonné.
  def errors_reported_during
    collector = Collector.new([])
    Rails.error.subscribe(collector)
    yield
    collector.errors
  ensure
    Rails.error.unsubscribe(collector)
  end
end

RSpec.configure do |config|
  config.include ProductionExceptions, :production_exceptions

  config.around(:each, :production_exceptions) do |example|
    env_config = Rails.application.env_config
    original = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env_config["action_dispatch.show_exceptions"] = :all
    env_config["action_dispatch.show_detailed_exceptions"] = false
    example.run
  ensure
    env_config.merge!(original)
  end
end
