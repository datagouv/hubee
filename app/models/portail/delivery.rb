# frozen_string_literal: true

module Portail
  # Le DÉTAIL d'une démarche : les champs de la liste, plus le demandeur — absent de la liste
  # servie en amont, présent au détail.
  #
  # `id` n'est lu par aucun écran aujourd'hui, et reste porté quand même : le détail porte
  # l'identité de ce qu'il décrit, faute de quoi le premier lien ou la première trace à écrire
  # rouvrirait la couche. C'est la règle que suit déjà l'amont, dont le paquet de données —
  # une partie d'une démarche, pas une ressource — n'a délibérément pas d'identifiant.
  Delivery = Data.define(
    :id, :number, :state, :data_stream_code, :transmitted_at, :updated_at, :applicant
  ) do
    include DeliveryDisplay

    # Le demandeur suit la même règle que les dates : la ligne s'affiche toujours, avec son
    # repli quand l'amont n'en sert pas. La masquer ferait disparaître une information sans
    # dire qu'elle manque.
    def display_applicant = applicant&.full_name.presence || DeliveryDisplay::MISSING
  end
end
