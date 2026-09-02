# frozen_string_literal: true

module Portail
  class Delivery
    # L'inventaire d'une pièce, jamais son contenu : l'amont ne sert aucun binaire. `state`
    # compte autant que `filename`, une pièce rejetée est une information que l'agent n'a
    # nulle part ailleurs.
    Attachment = Data.define(:id, :filename, :content_type, :byte_size, :kind, :state)
  end
end
