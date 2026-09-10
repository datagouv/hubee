# frozen_string_literal: true

module Portail
  class Delivery
    # Le contenu d'une pièce, accompagné de la démarche que l'amont a réellement servie. Cette
    # démarche n'est pas là pour l'affichage : elle est ce sur quoi la policy rejoue le bornage
    # après coup, comme le `policy_scope` de la liste le rejoue sur chaque ligne d'une page.
    # `body` ne traverse que la réponse — ni disque, ni journal.
    AttachmentContent = Data.define(:delivery, :attachment, :body)
  end
end
