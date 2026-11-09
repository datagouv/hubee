# frozen_string_literal: true

# Sans ces variables, la production démarre mais chaque courriel échoue (ou part avec un
# expéditeur et des liens vides) : panne au démarrage plutôt qu'à l'envoi.
# SECRET_KEY_BASE_DUMMY marque la précompilation des assets, qui démarre l'application sans
# aucun secret : les variables sont requises pour servir, pas pour construire l'image.
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  missing = %w[APP_HOST MAILER_FROM SMTP_USER_NAME SMTP_PASSWORD].select { ENV[it].blank? }
  raise "Variables d'envoi des courriels manquantes : #{missing.join(", ")}" if missing.any?
end
