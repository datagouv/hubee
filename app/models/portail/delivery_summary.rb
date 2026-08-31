# frozen_string_literal: true

module Portail
  # La forme LISTE d'une démarche. Le détail est un type distinct : la provenance est portée
  # par le type, jamais déduite de la nullité d'un champ.
  DeliverySummary = Data.define(
    :id, :number, :state, :data_stream, :transmitted_at, :updated_at
  )
end
