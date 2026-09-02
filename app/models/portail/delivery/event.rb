# frozen_string_literal: true

module Portail
  class Delivery
    # `si_comment` est réservé aux SI par le contrat amont et affiché quand même, sur décision
    # métier : seul le gabarit de l'historique le lit.
    Event = Data.define(
      :id, :event_type, :created_at, :author, :content, :si_comment, :metadata, :attachments
    )
  end
end
