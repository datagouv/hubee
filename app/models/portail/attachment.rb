# frozen_string_literal: true

module Portail
  # Une pièce jointe telle que le portail la MONTRE : son inventaire, jamais son contenu.
  #
  # L'amont ne sert aucun binaire — la gem n'expose aucune route de téléchargement — et le
  # portail ne prétend donc pas ouvrir ce qu'il liste. Ce n'est pas un manque à combler en
  # vitesse : streamer le fichier d'un SI tiers vers le navigateur d'un agent est une décision
  # de sécurité SecNumCloud, pas un ajout de gabarit.
  #
  # `state` compte autant que `filename` : une pièce rejetée ou corrompue est l'information que
  # l'agent n'a nulle part ailleurs, et c'est elle qui justifie l'inventaire à elle seule.
  Attachment = Data.define(:id, :filename, :content_type, :byte_size, :kind, :state)
end
