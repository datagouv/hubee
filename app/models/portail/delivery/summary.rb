# frozen_string_literal: true

module Portail
  class Delivery
    # La forme liste d'une démarche. Un type distinct du détail : la provenance est portée par
    # le type, jamais déduite de la nullité d'un champ.
    Summary = Data.define(
      :id, :number, :state, :data_stream, :recipient, :transmitted_at, :updated_at
    )
  end
end
