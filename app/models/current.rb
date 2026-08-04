# frozen_string_literal: true

# La session du portail pour la requête en cours. Remise à zéro par Rails entre deux
# requêtes : rien n'y survit d'un agent à l'autre.
class Current < ActiveSupport::CurrentAttributes
  attribute :provider_session

  delegate :membership, to: :provider_session, allow_nil: true
  delegate :agent, to: :membership, allow_nil: true
end
