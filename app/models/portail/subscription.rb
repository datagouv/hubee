# frozen_string_literal: true

module Portail
  # L'abonnement d'une organisation à un flux, dans le modèle V2 : des permissions et un mode
  # d'accès, pas de statut. Homonyme de ::Subscription, le modèle ActiveRecord : dans
  # `module Portail`, un `Subscription` nu résout vers cette constante-ci.
  class Subscription < Data.define(:id, :data_stream, :read_package, :create_package, :access_mode)
    PORTAL_ACCESS = "portal"

    # Ce qui fait proposer un flux au filtre : l'organisation le reçoit, et par le portail.
    # L'amont ne sert pour l'heure que les dossiers de ces abonnements-là.
    def readable_via_portal? = read_package && access_mode == PORTAL_ACCESS
  end
end
