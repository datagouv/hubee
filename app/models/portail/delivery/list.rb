# frozen_string_literal: true

module Portail
  class Delivery
    # Ce que la frontière rend pour une liste : les télédossiers servis, et la page qui les situe.
    # Les télédossiers n'atteignent une vue qu'une fois passés par la policy.
    List = Data.define(:deliveries, :page)
  end
end
