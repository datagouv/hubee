# frozen_string_literal: true

# La gem n'est pas auto-requise (groupe Bundler hors `default`), et pas de rescue : tout
# environnement qui boote l'application l'a au bundle.
require "hub_api_v1"

# Depuis la 2.0.0, le corps des réponses d'erreur amont a quitté les messages d'exception :
# sans ce branchement, il n'est écrit nulle part.
HubApiV1.logger = Rails.logger
