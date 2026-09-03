# frozen_string_literal: true

module Portail
  # Le flux d'une démarche. Homonyme de ::DataStream, le modèle ActiveRecord : dans
  # `module Portail`, un `DataStream` nu résout vers cette constante-ci.
  DataStream = Data.define(:code)
end
