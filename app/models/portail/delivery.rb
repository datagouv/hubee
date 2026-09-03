# frozen_string_literal: true

module Portail
  # Le détail d'une démarche : les champs de la liste, plus le demandeur, les pièces du dépôt
  # et l'historique. `attachments` ne porte que les pièces du dépôt initial, celles apportées
  # ensuite vivent sur leur event. L'affichage vit dans Portail::DeliveriesHelper.
  Delivery = Data.define(
    :id, :number, :state, :data_stream, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  )
end
