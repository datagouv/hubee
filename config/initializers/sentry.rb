if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.send_default_pii = false
    # Désactivé par défaut dans sentry-rails : sans lui, ce que le code signale par
    # `Rails.error.report` ne partirait nulle part.
    config.rails.register_error_subscriber = true
  end
end
