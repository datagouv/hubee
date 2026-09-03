# frozen_string_literal: true

module Portail
  # Une ligne d'historique, immuable en amont. `si_comment` est réservé aux SI par le contrat
  # amont et affiché quand même, sur décision métier : le gabarit de l'historique est le seul
  # à le lire.
  Event = Data.define(
    :id, :event_type, :created_at, :author, :content, :si_comment, :metadata, :attachments
  )
end
