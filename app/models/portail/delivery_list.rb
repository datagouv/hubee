# frozen_string_literal: true

module Portail
  # Une page de démarches et de quoi la situer. `counts_by_state` est complet et ordonné :
  # c'est lui qui donne l'ordre des états au portail, seul et sans qu'aucun écran n'ait à
  # connaître la liste des états de l'amont.
  DeliveryList = Data.define(:deliveries, :pagination, :counts_by_state)
end
