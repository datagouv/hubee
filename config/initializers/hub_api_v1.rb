# frozen_string_literal: true

# Sans ce logger, les erreurs de lecture des dates renvoyées par l'API sont silencieuses.
# Le rescue préserve le démarrage là où le bundle exclut la gem, et journalise le message :
# une dépendance de la gem introuvable ne doit pas passer pour une absence volontaire.
begin
  require "hub_api_v1"
  HubApiV1.logger = Rails.logger
rescue LoadError => e
  Rails.logger.info("hub-api-v1 non chargée, client d'API non configuré — #{e.message}")
end
