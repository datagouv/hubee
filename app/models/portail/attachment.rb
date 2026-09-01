# frozen_string_literal: true

module Portail
  # Une pièce jointe telle que le portail la MONTRE : son inventaire, jamais son contenu.
  #
  # L'amont ne sert aucun binaire et le portail ne prétend donc pas ouvrir ce qu'il liste.
  # Streamer le fichier d'un SI tiers vers le navigateur d'un agent est une décision de
  # sécurité SecNumCloud, pas un ajout de gabarit.
  #
  # `state` compte autant que `filename` : une pièce rejetée ou corrompue est l'information que
  # l'agent n'a nulle part ailleurs.
  Attachment = Data.define(:id, :filename, :content_type, :byte_size, :kind, :state)
end
