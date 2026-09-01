# frozen_string_literal: true

# Sans ce logger, les erreurs de lecture des dates renvoyées par l'API sont silencieuses.
#
# `require` explicite : la gem vit dans un groupe hors `default`, Bundler ne la requiert jamais
# seule et Zeitwerk n'autocharge pas les constantes de gems. Le rescue préserve le démarrage là
# où le bundle l'exclut, et journalise le message : il attrape aussi bien la gem absente qu'une
# de SES dépendances introuvable, qu'on ne veut pas confondre avec une absence volontaire.
begin
  require "hub_api_v1"
  HubApiV1.logger = Rails.logger
rescue LoadError => e
  Rails.logger.info("hub-api-v1 non chargée, client d'API non configuré — #{e.message}")
end
