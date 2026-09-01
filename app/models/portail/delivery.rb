# frozen_string_literal: true

module Portail
  # Le DÉTAIL d'une démarche : les champs de la liste, plus ce que l'amont ne sert qu'ici — le
  # demandeur, les pièces du dépôt et l'historique.
  #
  # `id` n'est lu par aucun écran aujourd'hui, et reste porté quand même : le détail porte
  # l'identité de ce qu'il décrit, faute de quoi le premier lien ou la première trace à écrire
  # rouvrirait la couche. C'est la règle que suit déjà l'amont, dont le paquet de données —
  # une partie d'une démarche, pas une ressource — n'a délibérément pas d'identifiant.
  #
  # `attachments` ne porte QUE les pièces du dépôt initial. Celles déposées en cours de route
  # vivent sur l'event qui les a apportées, et n'en sont pas extraites ici : leur provenance
  # est justement ce que l'écran montre, et un inventaire fusionné la perdrait. Les deux
  # magasins sont distincts en amont, ils le restent ici.
  #
  # L'affichage vit dans Portail::DeliveriesHelper, pas ici : voir le motif là-bas.
  Delivery = Data.define(
    :id, :number, :state, :data_stream, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  )
end
