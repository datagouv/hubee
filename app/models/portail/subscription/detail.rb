# frozen_string_literal: true

module Portail
  class Subscription
    # Le détail d'un abonnement : l'abonnement tel que la liste le sert, ses courriels de
    # télédossiers et l'éditeur qui s'y connecte. La délégation n'existe qu'en mode API.
    Detail = Data.define(:subscription, :delivery_email_configuration, :delegation)
  end
end
