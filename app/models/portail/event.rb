# frozen_string_literal: true

module Portail
  # Une ligne d'historique. Immuable en amont, donc sans date de modification : en porter une
  # contredirait le modèle qu'on affiche.
  #
  # Deux textes, jamais fusionnés. `content` est le message d'échange, sans restriction.
  # `si_comment` est contractuellement réservé aux SI par le swagger V1 (« non aux OSL »), et
  # le portail l'affiche quand même : décision métier prise le 2026-09-01, au motif que les
  # agents du portail opèrent depuis un SI et en sont donc destinataires. Elle est écrite ici
  # parce qu'elle n'est pas déductible du code ; si cette lecture change, la coupure se fait
  # dans le gabarit de l'historique, qui est le seul endroit à lire ce champ.
  Event = Data.define(
    :id, :event_type, :created_at, :author, :content, :si_comment, :metadata, :attachments
  )
end
