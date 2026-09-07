# frozen_string_literal: true

module Portail
  class Delivery
    # Ce qui situe une page de démarches, sans les démarches elles-mêmes : servies à part, elles
    # n'atteignent une vue qu'une fois passées par la policy. `counts_by_state` est complet et
    # ordonné : c'est lui qui donne au portail la liste des états.
    Page = Data.define(:pagination, :counts_by_state)
  end
end
