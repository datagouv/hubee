require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Hubee
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    #
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Paris"
    config.i18n.default_locale = :fr

    # Aucune variante d'image n'est générée : les fichiers échangés sont des documents,
    # jamais des images redimensionnées. Désactiver le processeur retire de la surface
    # d'attaque tout le traitement de variantes (cf. CVE-2026-66066).
    config.active_storage.variant_processor = :disabled

    # DSFR comme form builder par défaut (toutes les formes utilisent les helpers DSFR)
    config.action_view.default_form_builder = "Dsfr::FormBuilder"

    # Les erreurs du portail ont leurs pages DSFR ; celles de l'API gardent la réponse JSON
    # standard de Rails — un client d'API ne reçoit jamais de HTML.
    config.exceptions_app = lambda do |env|
      if env["action_dispatch.original_path"].to_s.start_with?("/api")
        ActionDispatch::PublicExceptions.new(Rails.public_path).call(env)
      else
        Rails.application.routes.call(env)
      end
    end
    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
