# frozen_string_literal: true

module Portail
  class Delivery
    # Ce que la frontière rend pour une liste : les démarches servies, et la page qui les situe.
    # Les démarches n'atteignent une vue qu'une fois passées par la policy.
    List = Data.define(:deliveries, :page)
  end
end
