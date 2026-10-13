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

    # Pages d'erreur rendues par l'application (layout DSFR) plutôt que les pages statiques
    config.exceptions_app = routes

    # `ip_address`, la clé du contexte des événements. Le contrôle ne compare que Client-IP et
    # X-Forwarded-For, sans écarter un X-Forwarded-For forgé seul : il privait d'IP la requête
    # suspecte. Rails retient l'adresse ajoutée par le proxy, fiable s'il réécrit ces en-têtes.
    config.action_dispatch.ip_spoofing_check = false
    config.log_tags = {request_id: :request_id, ip_address: :remote_ip}

    # Une requête, une ligne : la ligne de fin de requête reprend ce que Rails écrit à part
    # (config/initializers/request_log.rb), et les appenders retirent la ligne à part. Celle d'une
    # route inconnue ne porte que la pile du routeur ; celle d'un téléchargement nommait la pièce,
    # que la requête désigne déjà.
    redundant_metrics = %w[rails.controller.redirect_to rails.controller.halted_callback
      rails.controller.rescue_from_callback rails.controller.send_data]
    redundant_exceptions = [ActionController::RoutingError]
    config.x.log_filter = ->(log) do
      !redundant_metrics.include?(log.metric) && redundant_exceptions.none? { log.exception.is_a?(it) }
    end
    # Mot pour mot le message de l'exception levée ensuite, déjà journalisée.
    config.action_controller.log_warning_on_csrf_failure = false

    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
