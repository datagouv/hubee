require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # HTTPS géré côté applicatif — décision prise avec l'infra, qui s'alignera
  # ensuite. Le TLS est terminé par le reverse-proxy d'infra, qui transmet du
  # HTTP en clair au conteneur.
  # - assume_ssl : on considère toute requête comme arrivée en HTTPS. La
  #   redirection interne de force_ssl ne se déclenche donc jamais → aucune boucle
  #   de redirection possible, sans dépendre de X-Forwarded-Proto (dont on ne
  #   maîtrise pas la traversée proxy + Thruster).
  # - force_ssl : l'app devient source de vérité pour HSTS + flag Secure du cookie.
  config.assume_ssl = true
  config.force_ssl = true

  # Pas de config.ssl_options ici : assume_ssl neutralise la redirection de
  # force_ssl, donc /up n'est jamais redirigé (l'exclusion serait inutile).

  # Logs vers STDOUT au format logfmt (format conseillé par le CSIRT).
  # rails_semantic_logger remplace la stack de log ; l'appender `add` est créé dans
  # tous les process (web, jobs, rake), pas seulement en mode serveur.
  config.rails_semantic_logger.appenders do |appenders|
    appenders.add(io: $stdout, formatter: LogfmtFormatter.new, filter: config.x.log_filter)
  end

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = {database: {writing: :queue}}
  # Doit rester inférieur au délai d'arrêt du conteneur jobs, sinon il est tué avant la fin.
  config.solid_queue.shutdown_timeout = 60.seconds
  # Un mois d'historique pour retracer depuis quand une tâche récurrente ne tourne plus.
  config.solid_queue.clear_finished_jobs_after = 30.days

  # Envoi direct chez Brevo, sans relais. Les variables sont contrôlées au démarrage
  # (cf. config/initializers/action_mailer.rb).
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: "smtp-relay.brevo.com",
    port: 587,
    user_name: ENV["SMTP_USER_NAME"],
    password: ENV["SMTP_PASSWORD"],
    authentication: :plain,
    enable_starttls: true
  }
  # Un échec d'envoi doit faire échouer le job : visible et rejouable dans Solid Queue.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_options = {from: ENV["MAILER_FROM"]}
  config.action_mailer.default_url_options = {host: ENV["APP_HOST"], protocol: "https"}

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
