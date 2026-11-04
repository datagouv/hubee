# frozen_string_literal: true

module Portail
  class Subscription
    # L'éditeur qui se connecte à l'API pour l'organisation. Son nom vient du référentiel des
    # organisations et peut manquer : le couple seul l'identifie alors.
    Delegation = Data.define(:editor_siret, :editor_insee_code, :editor_name)
  end
end
