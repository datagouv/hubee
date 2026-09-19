# frozen_string_literal: true

module Portail
  class DataStream
    # Ce qu'un télédossier ou un abonnement porte du flux : son identité, sans aucune règle. Un
    # type distinct du flux entier : la provenance est portée par le type, jamais déduite de la
    # nullité d'un champ.
    Summary = Data.define(:code)
  end
end
