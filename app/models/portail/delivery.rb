# frozen_string_literal: true

module Portail
  # Le DÉTAIL d'une démarche : les champs de la liste, plus ce que l'amont ne sert qu'ici — le
  # demandeur, les pièces du dépôt et l'historique.
  #
  # `id` n'est lu par aucun écran aujourd'hui et reste porté quand même : le détail porte
  # l'identité de ce qu'il décrit, et la bascule vers un ::Delivery ActiveRecord est décidée —
  # le premier lien ou la première trace à écrire rouvrirait sinon la couche.
  #
  # `attachments` ne porte QUE les pièces du dépôt initial : celles déposées en cours de route
  # vivent sur l'event qui les a apportées, dont la provenance est ce que l'écran montre.
  #
  # L'affichage vit dans Portail::DeliveriesHelper, pas ici.
  Delivery = Data.define(
    :id, :number, :state, :data_stream, :transmitted_at, :updated_at,
    :applicant, :attachments, :events
  )
end
