# frozen_string_literal: true

module Portail
  class Delivery
    # Ce qui décrit une pièce, sans son contenu : celui-ci ne se rapatrie qu'à la demande, et
    # voyage à part (cf. AttachmentContent). `state` compte doublement : une pièce rejetée est
    # une information que l'agent n'a nulle part ailleurs, et seule une pièce reçue est livrable.
    Attachment = Data.define(:id, :filename, :content_type, :byte_size, :kind, :state)
  end
end
