# frozen_string_literal: true

module Portail
  # Le flux d'une démarche, réduit au code que le portail affiche.
  #
  # Un objet et non un code plat, alors que le portail ne lit que `code` : à terme la démarche
  # sera un ::Delivery ActiveRecord avec un `belongs_to :data_stream`, comme ::DataPackage en a
  # déjà un. Porter la forme d'arrivée dès maintenant évite un renommage en travers des vues,
  # de la policy et des specs le jour de la bascule.
  #
  # ⚠️ Homonyme de ::DataStream, le modèle ActiveRecord de la V2. Dans `module Portail`, un
  # `DataStream` nu résout vers CETTE constante — toujours écrire le nom complet.
  DataStream = Data.define(:code)
end
