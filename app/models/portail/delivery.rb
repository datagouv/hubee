# frozen_string_literal: true

module Portail
  # Le DÉTAIL d'une démarche : les champs de la liste, plus le demandeur — absent de la liste
  # servie en amont, présent au détail.
  Delivery = Data.define(
    :id, :number, :state, :data_stream_code, :transmitted_at, :updated_at, :applicant
  )
end
