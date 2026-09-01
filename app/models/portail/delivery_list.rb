# frozen_string_literal: true

module Portail
  # Une page de démarches et de quoi la situer. `counts_by_state` est complet et ordonné : il
  # donne au portail l'ordre des états, sans qu'aucun écran ait à connaître leur liste.
  DeliveryList = Data.define(:deliveries, :pagination, :counts_by_state)
end
