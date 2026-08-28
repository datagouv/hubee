# frozen_string_literal: true

module Portail
  # La forme LISTE d'une démarche. Le détail est un type distinct : la provenance est portée
  # par le type, jamais déduite de la nullité d'un champ.
  #
  # `data_stream_code` est plat là où l'amont imbrique un objet flux : le portail ne lit que
  # le code, et une indirection qui ne sert qu'à le traverser se paierait à chaque appel.
  DeliverySummary = Data.define(
    :id, :number, :state, :data_stream_code, :transmitted_at, :updated_at
  )
end
