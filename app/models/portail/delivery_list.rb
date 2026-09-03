# frozen_string_literal: true

module Portail
  # Une page de démarches. `counts_by_state` est complet et ordonné : c'est lui qui donne au
  # portail la liste des états.
  DeliveryList = Data.define(:deliveries, :pagination, :counts_by_state)
end
