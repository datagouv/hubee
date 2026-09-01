# frozen_string_literal: true

module Portail
  # Une ligne d'historique. Immuable en amont, donc sans date de modification.
  #
  # Deux textes, jamais fusionnés. `content` est le message d'échange, sans restriction.
  # `si_comment` est contractuellement réservé aux SI par le swagger V1 (« non aux OSL ») et le
  # portail l'affiche quand même : décision métier du 2026-09-01, les agents du portail opérant
  # depuis un SI. Si cette lecture change, la coupure se fait dans le gabarit de l'historique,
  # seul endroit à lire ce champ.
  Event = Data.define(
    :id, :event_type, :created_at, :author, :content, :si_comment, :metadata, :attachments
  )
end
