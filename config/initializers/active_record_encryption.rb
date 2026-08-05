# frozen_string_literal: true

# Les jetons ProConnect sont conservés en base (ProviderSession) : on les chiffre au repos.
#
# Rails ne lit ces clés que dans les credentials ; ce dépôt n'en a pas, tous ses secrets
# passent par l'environnement. Les deux variables ci-dessous sont donc les nôtres et non
# une convention Rails — `config.active_record.encryption` est la surface prévue pour les
# fournir, et elle a la priorité sur les credentials.
#
# Ni `deterministic_key` (rien n'est recherché par sa valeur chiffrée), ni
# `support_unencrypted_data` : la table naît avec cette branche, sans ligne en clair.
#
# Aucun repli hors production : une clé en dur dans un dépôt public, et une branche selon
# l'environnement qui dégraderait la protection si une recette était mal nommée. Les clés
# de développement et de test vivent dans .env et .env.test, comme les autres secrets.
Rails.application.configure do
  config.active_record.encryption.primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]
  config.active_record.encryption.key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]

  # Sans ce contrôle, l'absence de clé ne se découvrirait qu'à la première connexion d'un
  # agent. SECRET_KEY_BASE_DUMMY marque la précompilation des assets, qui démarre
  # l'application sans aucun secret et n'a rien à chiffrer.
  if config.active_record.encryption.primary_key.blank? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    raise "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY et ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT " \
          "sont requises — voir .env.example"
  end
end
