# frozen_string_literal: true

# Sans ce logger, les erreurs de lecture des dates renvoyées par l'API — format invalide,
# champ nul — sont silencieuses.
#
# Le require est explicite et non différé : la gem vit dans un groupe hors `default`, donc
# Bundler ne la requiert jamais seule, et Zeitwerk n'autocharge pas les constantes de gems.
# Un `defined?(HubApiV1)` serait faux ici et le logger ne serait jamais posé. Le rescue
# préserve le démarrage là où le bundle l'exclut — c'est lui, et non l'absence de require,
# qui tient cette garantie.
begin
  require "hub_api_v1"
  HubApiV1.logger = Rails.logger
rescue LoadError
  Rails.logger.info("hub-api-v1 absente du bundle : client d'API non configuré")
end
