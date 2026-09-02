# frozen_string_literal: true

module Portail
  # Le détail d'une démarche. `attachments` ne porte que les pièces du dépôt initial, celles
  # apportées ensuite vivent sur leur event. Ce qui n'existe qu'en elle vit sous ce namespace.
  Delivery = Data.define(
    :id, :number, :state, :data_stream, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  )
end
