# frozen_string_literal: true

# La session du portail pour la requête en cours. Remise à zéro par Rails entre deux
# requêtes : rien n'y survit d'un agent à l'autre.
#
# Exception assumée à la règle de namespace : ce qu'elle porte est propre à ::Portail et
# devrait s'y trouver, mais `Current` à la racine est la convention Rails et le nom que
# l'on cherchera. Si ::API se dote un jour d'un état par requête, les deux se disputeront
# la constante — c'est à ce moment-là qu'il faudra la déplacer sous Portail::Current.
class Current < ActiveSupport::CurrentAttributes
  attribute :provider_session

  delegate :membership, to: :provider_session, allow_nil: true
  delegate :agent, to: :membership, allow_nil: true
end
