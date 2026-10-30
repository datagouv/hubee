# frozen_string_literal: true

# Forme d'un code de flux V1, la même pour l'habilitation en base et pour l'API qui en reçoit.
module DataStreamCode
  # Des codes de production portent des accents : seul un espacement est refusé, Unicode compris
  # (\S laisserait passer une espace insécable). La gem encode le code qu'elle place dans un chemin.
  FORMAT = /\A[^[:space:]]{1,100}\z/
end
